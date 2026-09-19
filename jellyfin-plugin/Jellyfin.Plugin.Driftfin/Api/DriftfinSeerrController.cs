using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.Driftfin.Configuration;
using MediaBrowser.Controller;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Jellyfin.Plugin.Driftfin.Api
{
    [ApiController]
    [Route("Driftfin/v1/seerr")]
    [Authorize]
    [RequestSizeLimit(16384)]
    public sealed class DriftfinSeerrController : ControllerBase
    {
        private readonly IAuthorizationContext _auth;
        private readonly IUserManager _users;
        private readonly IServerApplicationHost _host;
        private readonly ILibraryManager _library;
        private readonly IntegrationClient _client;

        public DriftfinSeerrController(IAuthorizationContext auth, IUserManager users,
            IServerApplicationHost host, ILibraryManager library, IntegrationClient client)
        {
            _auth = auth;
            _users = users;
            _host = host;
            _library = library;
            _client = client;
        }

        [HttpGet("status")]
        [HttpGet("auth/me")]
        [HttpGet("service/sonarr")]
        [HttpGet("service/radarr")]
        [HttpGet("service/sonarr/{id:int:min(0)}")]
        [HttpGet("service/radarr/{id:int:min(0)}")]
        [HttpGet("user")]
        [HttpGet("user/{id:int:min(1)}/quota")]
        [HttpGet("user/{id:int:min(1)}/requests")]
        [HttpGet("movie/{id:int:min(1)}")]
        [HttpGet("tv/{id:int:min(1)}")]
        [HttpGet("tv/{id:int:min(1)}/season/{season:int:min(0)}")]
        [HttpGet("request")]
        [HttpGet("media")]
        [HttpGet("discover/trending")]
        [HttpGet("discover/movies")]
        [HttpGet("discover/movies/upcoming")]
        [HttpGet("discover/tv")]
        [HttpGet("discover/tv/upcoming")]
        [HttpGet("movie/{id:int:min(1)}/similar")]
        [HttpGet("movie/{id:int:min(1)}/recommendations")]
        [HttpGet("movie/{id:int:min(1)}/ratingscombined")]
        [HttpGet("tv/{id:int:min(1)}/similar")]
        [HttpGet("tv/{id:int:min(1)}/recommendations")]
        [HttpGet("tv/{id:int:min(1)}/ratings")]
        [HttpGet("person/{id:int:min(1)}/combined_credits")]
        [HttpGet("search")]
        [HttpGet("search/company")]
        [HttpGet("genres/movie")]
        [HttpGet("genres/tv")]
        [HttpGet("watchproviders/movies")]
        [HttpGet("watchproviders/tv")]
        [HttpGet("watchproviders/regions")]
        [HttpGet("certifications/movie")]
        [HttpGet("certifications/tv")]
        [HttpDelete("request/{id:int:min(1)}")]
        [HttpDelete("media/{id:int:min(1)}")]
        [HttpDelete("media/{id:int:min(1)}/file")]
        public Task<ActionResult> ReadOrDelete(CancellationToken cancellationToken) => Execute(default, cancellationToken);

        [HttpGet("/Driftfin/v1/discovery/search")]
        public Task<ActionResult> Discovery(CancellationToken cancellationToken) => Execute(default, cancellationToken, discovery: true);

        [HttpPost("request")]
        [HttpPost("request/{id:int:min(1)}/approve")]
        [HttpPost("media/{id:int:min(1)}/available")]
        [HttpPost("media/{id:int:min(1)}/partial")]
        [HttpPost("media/{id:int:min(1)}/processing")]
        [HttpPost("media/{id:int:min(1)}/pending")]
        [HttpPost("media/{id:int:min(1)}/unknown")]
        public Task<ActionResult> Write([FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)] JsonElement body,
            CancellationToken cancellationToken) => Execute(body, cancellationToken);

        private async Task<ActionResult> Execute(JsonElement body, CancellationToken cancellationToken, bool discovery = false)
        {
            var auth = await _auth.GetAuthorizationInfo(Request).ConfigureAwait(false);
            if (auth.UserId == Guid.Empty) return Unauthorized();
            var user = _users.GetUserById(auth.UserId);
            if (user is null) return Unauthorized();
            var policy = _users.GetUserDto(user).Policy;
            if (policy is null || policy.IsDisabled) return Forbid();
            var config = Plugin.Instance?.Configuration.Snapshot();
            if (config is null) return NotFound();
            var path = discovery ? "search" : Request.Path.Value!.Split("/seerr/", 2, StringSplitOptions.None).Last();
            try
            {
                if (path != "auth/me" && path != "status" && !path.EndsWith("/quota", StringComparison.Ordinal)
                    && !DriftfinCapabilitiesController.AllowsExternalCatalog(policy))
                    throw new IntegrationException("content_restricted", 403);
                var identity = await _client.ResolveSeerrIdentity(config, _host.SystemId, auth.UserId, cancellationToken).ConfigureAwait(false);
                var upstream = SeerrOperations.Validate(Request.Method, path, Request.Query, identity);
                JsonElement? payload = null;
                if (Request.Method == "POST")
                {
                    if (path == "request")
                    {
                        var request = SeerrOperations.RequestBody(body, identity);
                        await ValidateRequestOptions(config, request, identity, cancellationToken).ConfigureAwait(false);
                        payload = JsonSerializer.SerializeToElement(request);
                    }
                    else
                    {
                        if (body.ValueKind != JsonValueKind.Undefined
                            && (body.ValueKind != JsonValueKind.Object || body.EnumerateObject().Any())) SeerrOperations.Invalid();
                        payload = JsonSerializer.SerializeToElement(new { });
                    }
                }
                var response = await _client.SendAsync(config, IntegrationService.Seerr, new HttpMethod(Request.Method),
                    upstream, identity.Id, payload, cancellationToken).ConfigureAwait(false);
                if (Request.Method == "DELETE") return NoContent();
                if (Request.Method == "POST" && path == "request" && SeerrResponses.Int(response, "id") <= 0)
                    throw new IntegrationException("no_request_created", 409);
                response = await _client.EnrichCatalogRequests(config, response, identity, cancellationToken).ConfigureAwait(false);
                var matches = new LibraryMatches(_library, user, policy.EnableMediaPlayback);
                var projection = new SeerrResponses(identity, matches.Find);
                return Ok(discovery ? projection.Discovery(response) : projection.Project(path, response));
            }
            catch (IntegrationException error)
            {
                return StatusCode(error.Status, new { reason = error.Reason, correlationId = Guid.NewGuid().ToString("N") });
            }
            catch (Exception error) when (error is JsonException or InvalidOperationException or KeyNotFoundException or FormatException)
            {
                return StatusCode(502, new { reason = "invalid_response", correlationId = Guid.NewGuid().ToString("N") });
            }
        }

        private async Task ValidateRequestOptions(PluginConfiguration config, JsonObject request,
            SeerrIdentity identity, CancellationToken cancellationToken)
        {
            if (request["serverId"] is null)
            {
                if (request["profileId"] is not null || request["rootFolder"] is not null
                    || request["tags"] is JsonArray { Count: > 0 }) SeerrOperations.Invalid();
                return;
            }
            var service = SeerrOperations.Text(request, "mediaType") == "tv" ? "sonarr" : "radarr";
            var id = SeerrOperations.Number(request, "serverId", 0);
            var options = await _client.SendAsync(config, IntegrationService.Seerr, HttpMethod.Get,
                $"api/v1/service/{service}/{id}", identity.Id, null, cancellationToken).ConfigureAwait(false);
            ResolveRequestOptions(request, options);
        }

        internal static void ResolveRequestOptions(JsonObject request, JsonElement options)
        {
            if (request["profileId"] is not null && !ContainsId(options, "profiles", SeerrOperations.Number(request, "profileId", 0))) SeerrOperations.Invalid();
            if (request["tags"] is JsonArray tags)
                foreach (var tag in tags) if (!ContainsId(options, "tags", tag!.GetValue<int>())) SeerrOperations.Invalid();
            if (request["rootFolder"] is not null)
            {
                var alias = SeerrOperations.Text(request, "rootFolder");
                var folders = SeerrResponses.Property(options, "rootFolders");
                if (folders.ValueKind != JsonValueKind.Array) SeerrOperations.Invalid();
                foreach (var folder in folders.EnumerateArray())
                {
                    if (alias != "folder:" + SeerrResponses.Int(folder, "id")) continue;
                    var path = SeerrResponses.Property(folder, "path");
                    if (path.ValueKind != JsonValueKind.String) SeerrOperations.Invalid();
                    request["rootFolder"] = path.GetString();
                    return;
                }
                SeerrOperations.Invalid();
            }
        }

        private static bool ContainsId(JsonElement options, string key, int id)
        {
            var values = SeerrResponses.Property(options, key);
            return values.ValueKind == JsonValueKind.Array && values.EnumerateArray().Any(item => SeerrResponses.Int(item, "id") == id);
        }
    }
}
