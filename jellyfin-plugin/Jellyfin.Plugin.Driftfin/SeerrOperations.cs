using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;

namespace Jellyfin.Plugin.Driftfin
{
    // Mirrors the operations used by SeerrChopperService; deliberately excludes login,
    // arbitrary settings, user creation, and credential-bearing proxy endpoints.
    internal static class SeerrOperations
    {
        internal static string Validate(string method, string path, IQueryCollection query, SeerrIdentity identity)
        {
            var catalog = "page language";
            var list = "take skip filter sort sortDirection requestedBy";
            string allowed;
            if (method == "GET")
            {
                allowed = path switch
                {
                    "status" or "auth/me" => "",
                    "search" => "query page language",
                    "search/company" => "query page",
                    "request" => list,
                    "media" => "take skip filter sort",
                    "user" => "take skip sort",
                    "discover/trending" or "discover/movies/upcoming" or "discover/tv/upcoming" => catalog,
                    "discover/movies" or "discover/tv" => catalog + " sortBy genre studio keywords excludeKeywords " +
                        "primaryReleaseDateGte primaryReleaseDateLte firstAirDateGte firstAirDateLte " +
                        "withRuntimeGte withRuntimeLte voteAverageGte voteAverageLte voteCountGte voteCountLte " +
                        "watchRegion watchProviders certification certificationGte certificationLte certificationCountry certificationMode",
                    "service/sonarr" or "service/radarr" or "genres/movie" or "genres/tv" or
                        "watchproviders/regions" or "certifications/movie" or "certifications/tv" => "",
                    "watchproviders/movies" or "watchproviders/tv" => "watchRegion",
                    _ when Matches(path, @"^(movie|tv)/[1-9][0-9]*$") => "language",
                    _ when Matches(path, @"^(movie|tv)/[1-9][0-9]*/(similar|recommendations)$") => catalog,
                    _ when Matches(path, @"^(movie/[1-9][0-9]*/ratingscombined|tv/[1-9][0-9]*/ratings)$") => "",
                    _ when Matches(path, @"^tv/[1-9][0-9]*/season/[0-9]+$") => "language",
                    _ when Matches(path, @"^person/[1-9][0-9]*/combined_credits$") => "language",
                    _ when Matches(path, @"^service/(sonarr|radarr)/[0-9]+$") => "",
                    _ when Matches(path, @"^user/[1-9][0-9]*/requests$") => "take skip",
                    _ when Matches(path, @"^user/[1-9][0-9]*/quota$") => "",
                    _ => throw new IntegrationException("invalid_operation", 404),
                };
            }
            else if ((method == "POST" && (path == "request" || Matches(path, @"^request/[1-9][0-9]*/approve$")))
                || (method == "DELETE" && Matches(path, @"^request/[1-9][0-9]*$"))) allowed = "";
            else if ((method == "DELETE" && Matches(path, @"^media/[1-9][0-9]*(/file)?$"))
                || (method == "POST" && Matches(path, @"^media/[1-9][0-9]*/(available|partial|processing|pending|unknown)$")))
            {
                allowed = path.EndsWith("/file", StringComparison.Ordinal) ? "is4k" : "";
            }
            else throw new IntegrationException("invalid_operation", 404);

            if ((path == "media" || path.StartsWith("media/", StringComparison.Ordinal)
                    || path.EndsWith("/approve", StringComparison.Ordinal)) && !identity.HasPermission(16)) Denied();
            if (path == "user" && !identity.HasPermission(8)) Denied();
            if (path.StartsWith("user/", StringComparison.Ordinal))
            {
                var id = path.Split('/')[1];
                if (id != identity.Id.ToString(CultureInfo.InvariantCulture)) Denied();
            }

            var allowedKeys = allowed.Split(' ', StringSplitOptions.RemoveEmptyEntries).ToHashSet(StringComparer.Ordinal);
            var parts = new List<string>();
            foreach (var pair in query)
            {
                if (!allowedKeys.Contains(pair.Key) || pair.Value.Count != 1) Invalid();
                var value = pair.Value[0] ?? "";
                if (value.Length > (pair.Key == "query" ? 200 : 300) || value.Any(char.IsControl)) Invalid();
                switch (pair.Key)
                {
                    case "page": Integer(value, 1, 500); break;
                    case "take": Integer(value, 1, 100); break;
                    case "skip": Integer(value, 0, 10000); break;
                    case "requestedBy":
                        if (Integer(value, 1, int.MaxValue) != identity.Id) Denied();
                        break;
                    case "is4k": if (value != "true" && value != "false") Invalid(); break;
                    case "language": if (!Matches(value, "^[a-z]{2,3}(-[A-Z]{2})?$")) Invalid(); break;
                    case "query": if (string.IsNullOrWhiteSpace(value)) Invalid(); break;
                    default:
                        // Filter values are data, not paths. Seerr validates their catalog semantics.
                        if (!Matches(value, @"^[a-zA-Z0-9 _.,|!:\-]*$")) Invalid();
                        break;
                }
                parts.Add(Uri.EscapeDataString(pair.Key) + "=" + Uri.EscapeDataString(value));
            }

            if ((path == "search" || path == "search/company") && !query.ContainsKey("query")) Invalid();
            return "api/v1/" + path + (parts.Count == 0 ? "" : "?" + string.Join("&", parts));
        }

        internal static JsonObject RequestBody(JsonElement body, SeerrIdentity identity)
        {
            if (body.ValueKind != JsonValueKind.Object) Invalid();
            var allowed = new HashSet<string> { "mediaType", "mediaId", "is4k", "seasons", "serverId", "profileId", "rootFolder", "tags", "userId" };
            var seen = new HashSet<string>();
            foreach (var field in body.EnumerateObject()) if (!allowed.Contains(field.Name) || !seen.Add(field.Name)) Invalid();
            var result = JsonNode.Parse(body.GetRawText())!.AsObject();
            var type = Text(result, "mediaType");
            if (type != "movie" && type != "tv") Invalid();
            Number(result, "mediaId", 1);
            var is4k = false;
            if (result["is4k"] is not null)
            {
                if (result["is4k"] is not JsonValue flag || !flag.TryGetValue<bool>(out var enabled)) Invalid();
                else is4k = enabled;
            }
            var permission = is4k ? type == "tv" ? 1024 | 4096 : 1024 | 2048 : type == "tv" ? 32 | 524288 : 32 | 262144;
            if (!identity.HasPermission(permission)) Denied();

            if (result["userId"] is not null && Number(result, "userId", 1) != identity.Id) Denied();
            // Attribution always comes from X-API-User. Do not invoke Seerr's on-behalf-of quota exemption.
            result.Remove("userId");
            foreach (var key in new[] { "seasons", "tags" })
            {
                if (result[key] is null) continue;
                if (result[key] is not JsonArray values || values.Count > 200) Invalid();
                else foreach (var value in values)
                {
                    if (value is not JsonValue number || !number.TryGetValue<int>(out var n) || n < 0 || n > 100000) Invalid();
                }
            }
            foreach (var key in new[] { "serverId", "profileId" }) if (result[key] is not null) Number(result, key, 0);
            if (result["rootFolder"] is not null && !Matches(Text(result, "rootFolder"), "^folder:[0-9]+$")) Invalid();
            return result;
        }

        internal static int Number(JsonObject body, string key, int minimum)
        {
            if (body[key] is JsonValue value && value.TryGetValue<int>(out var number) && number >= minimum) return number;
            throw new IntegrationException("invalid_input", 400);
        }

        internal static string Text(JsonObject body, string key)
        {
            if (body[key] is JsonValue value && value.TryGetValue<string>(out var text)) return text;
            throw new IntegrationException("invalid_input", 400);
        }

        private static int Integer(string value, int min, int max)
        {
            if (int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var number) && number >= min && number <= max) return number;
            throw new IntegrationException("invalid_input", 400);
        }

        internal static bool Matches(string value, string pattern) => Regex.IsMatch(value, pattern, RegexOptions.CultureInvariant, TimeSpan.FromMilliseconds(100));
        internal static void Invalid() => throw new IntegrationException("invalid_input", 400);
        internal static void Denied() => throw new IntegrationException("permission_denied", 403);
    }
}
