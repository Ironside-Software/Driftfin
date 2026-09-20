using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.Driftfin.Configuration;
using MediaBrowser.Controller;
using MediaBrowser.Controller.Plugins;
using Microsoft.Extensions.DependencyInjection;

namespace Jellyfin.Plugin.Driftfin
{
    public sealed class ServiceRegistrator : IPluginServiceRegistrator
    {
        public void RegisterServices(IServiceCollection services, IServerApplicationHost applicationHost)
        {
            services.AddHttpClient<IntegrationClient>()
                .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
                {
                    AllowAutoRedirect = false,
                    UseCookies = false,
                });
        }
    }

    public enum IntegrationService { Seerr, Sonarr, Radarr }

    // Only stable reason codes cross the plugin boundary, never upstream bodies or exceptions.
    public sealed class IntegrationException : Exception
    {
        public IntegrationException(string reason, int status = 502) : base(reason)
        {
            Reason = reason;
            Status = status;
        }

        public string Reason { get; }
        public int Status { get; }
    }

    public sealed class IntegrationClient
    {
        internal const int MaximumResponseBytes = 4 * 1024 * 1024;
        private readonly HttpClient _client;

        public IntegrationClient(HttpClient client) => _client = client;

        internal async Task<JsonElement> EnrichCatalogRequests(PluginConfiguration config, JsonElement response,
            SeerrIdentity identity, CancellationToken cancellationToken, Func<JsonElement, bool>? hasLocalSeries = null)
        {
            if (response.ValueKind != JsonValueKind.Object) return response;
            var body = JsonNode.Parse(response.GetRawText())!.AsObject();
            var details = new Dictionary<string, JsonElement>();
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            deadline.CancelAfter(TimeSpan.FromSeconds(15));
            try
            {
                foreach (var key in new[] { "results", "cast", "crew" })
                {
                    if (body[key] is not JsonArray items) continue;
                    if (key == "results" && items.Count > 100) throw new IntegrationException("invalid_response");
                    foreach (var entry in items)
                    {
                        if (entry is not JsonObject item) continue;
                        var type = item["mediaType"]?.GetValue<string>();
                        if (type != "movie" && type != "tv") continue;
                        var needsOwnership = item["mediaInfo"] is JsonObject info && info["requests"] is not JsonArray;
                        var needsEpisodes = type == "tv" && item["numberOfEpisodes"] is null
                            && hasLocalSeries?.Invoke(JsonSerializer.SerializeToElement(item)) == true;
                        if (!needsOwnership && !needsEpisodes) continue;
                        var id = (item["tmdbId"] ?? item["id"])?.GetValue<int>();
                        if (id is null or <= 0) continue;
                        var route = $"api/v1/{type}/{id}";
                        if (!details.TryGetValue(route, out var detail))
                        {
                            // Seerr search returns global media state without requests.
                            // Its detail endpoint supplies ownership; projection then filters it.
                            detail = await SendAsync(config, IntegrationService.Seerr, HttpMethod.Get,
                                route, identity.Id, null, deadline.Token).ConfigureAwait(false);
                            details[route] = detail;
                        }
                        if (detail.TryGetProperty("mediaInfo", out var mediaInfo)) item["mediaInfo"] = JsonNode.Parse(mediaInfo.GetRawText());
                        if (type == "tv")
                            foreach (var field in new[] { "numberOfEpisodes", "seasons" })
                                if (detail.TryGetProperty(field, out var value)) item[field] = JsonNode.Parse(value.GetRawText());
                    }
                }
                return JsonSerializer.SerializeToElement(body);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                throw new IntegrationException("unreachable");
            }
        }

        internal async Task<SeerrIdentity> ResolveSeerrIdentity(
            PluginConfiguration config, string serverId, Guid userId, CancellationToken cancellationToken)
        {
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            deadline.CancelAfter(TimeSpan.FromSeconds(15));
            try
            {
                var status = await SendAsync(config, IntegrationService.Seerr, HttpMethod.Get,
                    "api/v1/status", null, null, deadline.Token).ConfigureAwait(false);
                // Only enable versions whose identity contract is covered by our live fixtures.
                if (!status.TryGetProperty("version", out var version) || version.GetString()?.TrimStart('v') != "3.4.1")
                {
                    throw new IntegrationException("unsupported_version", 503);
                }

                var pairing = await SendAsync(config, IntegrationService.Seerr, HttpMethod.Get,
                    "api/v1/settings/jellyfin", null, null, deadline.Token).ConfigureAwait(false);
                if (!pairing.TryGetProperty("serverId", out var pairedServer)
                    || !string.Equals(pairedServer.GetString(), serverId, StringComparison.OrdinalIgnoreCase))
                {
                    throw new IntegrationException("server_not_linked", 403);
                }

                int? mappedId = null;
                for (var skip = 0; skip < 10000; skip += 100)
                {
                    var page = await SendAsync(config, IntegrationService.Seerr, HttpMethod.Get,
                        $"api/v1/user?take=100&skip={skip}&sort=created", null, null, deadline.Token).ConfigureAwait(false);
                    if (!page.TryGetProperty("results", out var users) || users.ValueKind != JsonValueKind.Array)
                    {
                        throw new IntegrationException("invalid_response");
                    }

                    foreach (var user in users.EnumerateArray())
                    {
                        if (!user.TryGetProperty("jellyfinUserId", out var linked)
                            || linked.ValueKind != JsonValueKind.String
                            || !Guid.TryParse(linked.GetString(), out var linkedId) || linkedId != userId) continue;
                        if (mappedId.HasValue || !user.TryGetProperty("id", out var id)
                            || !id.TryGetInt32(out var candidate) || candidate <= 0)
                        {
                            throw new IntegrationException("user_not_linked", 403);
                        }

                        mappedId = candidate;
                    }

                    if (users.GetArrayLength() < 100)
                    {
                        if (!mappedId.HasValue) throw new IntegrationException("user_not_linked", 403);
                        var me = await SendAsync(config, IntegrationService.Seerr, HttpMethod.Get,
                            "api/v1/auth/me", mappedId, null, deadline.Token).ConfigureAwait(false);
                        if (!me.TryGetProperty("id", out var currentId) || !currentId.TryGetInt32(out var actual)
                            || actual != mappedId.Value || !me.TryGetProperty("permissions", out var permissions)
                            || !permissions.TryGetInt64(out var rights))
                        {
                            throw new IntegrationException("unsupported_version", 503);
                        }

                        return new SeerrIdentity(actual, rights);
                    }
                }

                // Fail closed if a complete, unambiguous mapping cannot be established within the bound.
                throw new IntegrationException("user_not_linked", 403);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                throw new IntegrationException("unreachable");
            }
        }

        internal static (Uri BaseUri, string Key) Destination(PluginConfiguration config, IntegrationService service)
        {
            var (enabled, url, key) = service switch
            {
                IntegrationService.Seerr => (config.SeerrEnabled, config.SeerrUrl, config.SeerrApiKey),
                IntegrationService.Sonarr => (config.SonarrEnabled, config.SonarrUrl, config.SonarrApiKey),
                IntegrationService.Radarr => (config.RadarrEnabled, config.RadarrUrl, config.RadarrApiKey),
                _ => throw new IntegrationException("not_configured", 503),
            };
            if (!enabled || string.IsNullOrWhiteSpace(key) || string.IsNullOrWhiteSpace(url))
            {
                throw new IntegrationException("not_configured", 503);
            }

            if (!Uri.TryCreate(url.Trim().TrimEnd('/') + "/", UriKind.Absolute, out var uri)
                || (uri.Scheme != "https" && uri.Scheme != "http")
                || uri.UserInfo.Length != 0 || uri.Query.Length != 0 || uri.Fragment.Length != 0
                || key.Contains('\r') || key.Contains('\n'))
            {
                throw new IntegrationException("invalid_configuration", 503);
            }

            return (uri, key);
        }

        // Callers construct paths from explicit operations, never from a client-supplied URL.
        internal async Task<JsonElement> SendAsync(
            PluginConfiguration config, IntegrationService service, HttpMethod method,
            string path, int? seerrUserId, JsonElement? body, CancellationToken cancellationToken)
        {
            var (baseUri, key) = Destination(config, service);
            var route = path.Split('?')[0];
            if (!route.StartsWith("api/", StringComparison.Ordinal)
                || route.Contains("..", StringComparison.Ordinal) || route.Contains('\\')
                || path.Contains('#') || route.Contains('%'))
            {
                throw new IntegrationException("invalid_operation", 400);
            }

            if (service == IntegrationService.Seerr && !seerrUserId.HasValue
                && (method != HttpMethod.Get || (route != "api/v1/status" && route != "api/v1/auth/me"
                    && route != "api/v1/settings/jellyfin" && route != "api/v1/user")))
            {
                throw new IntegrationException("user_not_linked", 403);
            }

            using var request = new HttpRequestMessage(method, new Uri(baseUri, path));
            request.Headers.Add("X-Api-Key", key);
            if (seerrUserId.HasValue)
            {
                if (service != IntegrationService.Seerr || seerrUserId.Value <= 0)
                {
                    throw new IntegrationException("user_not_linked", 403);
                }

                request.Headers.Add("X-API-User", seerrUserId.Value.ToString(System.Globalization.CultureInfo.InvariantCulture));
            }

            if (body.HasValue)
            {
                request.Content = new StringContent(body.Value.GetRawText(), Encoding.UTF8, "application/json");
            }

            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            deadline.CancelAfter(TimeSpan.FromSeconds(10));
            try
            {
                using var response = await _client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, deadline.Token)
                    .ConfigureAwait(false);
                if (!response.IsSuccessStatusCode)
                {
                    throw new IntegrationException(response.StatusCode switch
                    {
                        HttpStatusCode.Unauthorized => "invalid_credentials",
                        HttpStatusCode.Forbidden => "permission_denied",
                        HttpStatusCode.TooManyRequests => "rate_limited",
                        _ => "upstream_error",
                    }, response.StatusCode == HttpStatusCode.Forbidden ? 403 : 502);
                }

                if (response.StatusCode == HttpStatusCode.NoContent)
                {
                    return JsonSerializer.SerializeToElement(new { });
                }

                if (response.Content.Headers.ContentLength > MaximumResponseBytes)
                {
                    throw new IntegrationException("invalid_response");
                }

                await using var stream = await response.Content.ReadAsStreamAsync(deadline.Token).ConfigureAwait(false);
                using var buffer = new MemoryStream();
                var chunk = new byte[8192];
                int count;
                while ((count = await stream.ReadAsync(chunk, deadline.Token).ConfigureAwait(false)) != 0)
                {
                    if (buffer.Length + count > MaximumResponseBytes)
                    {
                        throw new IntegrationException("invalid_response");
                    }

                    buffer.Write(chunk, 0, count);
                }

                using var json = JsonDocument.Parse(buffer.GetBuffer().AsMemory(0, (int)buffer.Length));
                return json.RootElement.Clone();
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                throw new IntegrationException("unreachable");
            }
            catch (HttpRequestException)
            {
                throw new IntegrationException("unreachable");
            }
            catch (IOException)
            {
                throw new IntegrationException("unreachable");
            }
            catch (JsonException)
            {
                throw new IntegrationException("invalid_response");
            }
        }
    }

    internal sealed record SeerrIdentity(int Id, long Permissions)
    {
        internal bool HasPermission(long permission) => (Permissions & 2) != 0 || (Permissions & permission) != 0;
    }
}
