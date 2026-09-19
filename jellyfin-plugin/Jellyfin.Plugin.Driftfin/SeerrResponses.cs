using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Jellyfin.Plugin.Driftfin
{
    // The managed wire format is the subset consumed by the existing Dart models.
    // Every nested object is projected separately; no upstream object is copied wholesale.
    internal sealed class SeerrResponses
    {
        private readonly SeerrIdentity _identity;
        private readonly Func<string, JsonElement, LibraryMatch?> _match;

        internal SeerrResponses(SeerrIdentity identity, Func<string, JsonElement, LibraryMatch?> match)
        {
            _identity = identity;
            _match = match;
        }

        internal JsonObject Discovery(JsonElement value)
        {
            var response = Pick(value, "page totalPages");
            var results = new JsonArray();
            var source = Property(value, "results");
            if (source.ValueKind != JsonValueKind.Array || source.GetArrayLength() > 100) throw new IntegrationException("invalid_response");
            foreach (var item in source.EnumerateArray())
            {
                var type = Type(item);
                if (type != "movie" && type != "tv" || Int(item, "id") <= 0) continue;
                var card = Images(Pick(item, "title name overview releaseDate firstAirDate"), item, "posterPath backdropPath");
                card["mediaType"] = type;
                card["tmdbId"] = Int(item, "id");
                var match = _match(type, item);
                var info = Media(Property(item, "mediaInfo"), type, true, item);
                var requested = info["requests"]!.AsArray().Any(request => request?["status"]?.GetValue<int>() is 1 or 2);
                var permitted = _identity.HasPermission(type == "movie" ? 32 | 262144 | 1024 | 2048 : 32 | 524288 | 1024 | 4096);
                var availability = match is not null ? match.Status == 5 ? "available" : "partial"
                    : requested ? "requested" : permitted ? "requestable" : "unavailable";
                card["availability"] = availability;
                card["libraryItemId"] = match?.ItemId;
                card["canPlay"] = match?.Playable == true;
                card["canRequest"] = permitted && availability != "available" && (type == "tv" || !requested);
                results.Add(card);
            }
            response["results"] = results;
            return response;
        }

        internal JsonNode Project(string path, JsonElement value)
        {
            if (path == "status") return Pick(value, "version");
            if (path == "auth/me") return User(value, true);
            if (path == "user") return Page(value, item => User(item, false));
            if (path.EndsWith("/quota", StringComparison.Ordinal))
            {
                var result = new JsonObject();
                foreach (var type in new[] { "movie", "tv" })
                    if (value.TryGetProperty(type, out var quota)) result[type] = Pick(quota, "days limit used remaining restricted");
                return result;
            }
            if (path == "request" || path.EndsWith("/requests", StringComparison.Ordinal))
                return value.TryGetProperty("results", out _) ? Page(value, Request) : Request(value);
            if (path.StartsWith("request/", StringComparison.Ordinal)) return Request(value);
            if (path == "media") return Page(value, item => Media(item, Type(item), true));
            if (path.StartsWith("media/", StringComparison.Ordinal)) return Media(value, Type(value), true);
            if (path.StartsWith("service/", StringComparison.Ordinal)) return Service(value);
            if (path.StartsWith("genres/", StringComparison.Ordinal)) return Array(value, item => Pick(item, "id name"));
            if (path == "watchproviders/regions") return Array(value, item => Pick(item, "iso_3166_1 english_name native_name"));
            if (path.StartsWith("watchproviders/", StringComparison.Ordinal))
                return Array(value, item => Images(Pick(item, "id name displayPriority"), item, "logoPath"));
            if (path.StartsWith("certifications/", StringComparison.Ordinal))
            {
                var countries = new JsonObject();
                if (value.TryGetProperty("certifications", out var map) && map.ValueKind == JsonValueKind.Object)
                    foreach (var country in map.EnumerateObject())
                        if (SeerrOperations.Matches(country.Name, "^[A-Z]{2}$")) countries[country.Name] = Array(country.Value, item => Pick(item, "certification meaning order"));
                return new JsonObject { ["certifications"] = countries };
            }
            if (path.EndsWith("/ratingscombined", StringComparison.Ordinal))
            {
                var ratings = new JsonObject();
                foreach (var key in new[] { "rt", "imdb" })
                    if (value.TryGetProperty(key, out var rating)) ratings[key] = Rating(rating);
                return ratings;
            }
            if (path.EndsWith("/ratings", StringComparison.Ordinal)) return Rating(value);
            if (path.Contains("/season/", StringComparison.Ordinal))
            {
                var season = Images(Pick(value, "id name overview seasonNumber"), value, "posterPath");
                AddArray(season, value, "episodes", item => Images(Pick(item, "id name overview episodeNumber seasonNumber airDate voteAverage voteCount"), item, "stillPath"));
                return season;
            }
            if (path.EndsWith("/combined_credits", StringComparison.Ordinal))
            {
                var credits = Pick(value, "id");
                foreach (var key in new[] { "cast", "crew" }) AddArray(credits, value, key, item => Catalog(item, Type(item)));
                return credits;
            }
            if (path == "search/company") return Page(value, item => Images(Pick(item, "id name originCountry"), item, "logoPath"));
            if (path == "search" || path.StartsWith("discover/", StringComparison.Ordinal)
                || path.EndsWith("/similar", StringComparison.Ordinal) || path.EndsWith("/recommendations", StringComparison.Ordinal))
                return Page(value, item => Catalog(item, Type(item)));
            return Catalog(value, path.StartsWith("tv/", StringComparison.Ordinal) ? "tv" : "movie");
        }

        internal JsonObject Catalog(JsonElement value, string type)
        {
            var result = Images(Pick(value, "id mediaType title name originalTitle originalName overview releaseDate firstAirDate lastAirDate " +
                "voteAverage voteCount runtime numberOfSeasons numberOfEpisodes character job department"), value,
                "posterPath backdropPath profilePath");
            if (value.TryGetProperty("mediaInfo", out var info)) result["mediaInfo"] = Media(info, type, true, value);
            else if (type == "movie" || type == "tv") result["mediaInfo"] = Media(default, type, true, value);
            AddArray(result, value, "genres", item => Pick(item, "id name"));
            AddArray(result, value, "keywords", item => Pick(item, "id name"));
            AddArray(result, value, "seasons", item => Images(Pick(item, "id name overview seasonNumber episodeCount"), item, "posterPath"));
            AddArray(result, value, "episodes", item => Images(Pick(item, "id name overview episodeNumber seasonNumber airDate voteAverage voteCount"), item, "stillPath"));
            if (value.TryGetProperty("externalIds", out var ids)) result["externalIds"] = Pick(ids, "imdbId tvdbId facebookId instagramId twitterId");
            if (value.TryGetProperty("credits", out var credits))
            {
                var people = new JsonObject();
                foreach (var key in new[] { "cast", "crew" }) AddArray(people, credits, key,
                    item => Images(Pick(item, "id castId character creditId gender name order job department"), item, "profilePath"));
                result["credits"] = people;
            }
            AddArray(result, value, "relatedVideos", item => Pick(item, "key name size type site"));
            if (value.TryGetProperty("contentRatings", out var contentRatings))
            {
                var entries = contentRatings.ValueKind == JsonValueKind.Array ? contentRatings : Property(contentRatings, "results");
                result["contentRatings"] = Array(entries, item => Pick(item, "iso_3166_1 rating"));
            }
            if (value.TryGetProperty("releases", out var releases))
            {
                result["releases"] = new JsonObject { ["results"] = Array(Property(releases, "results"), item =>
                {
                    var release = Pick(item, "iso_3166_1");
                    AddArray(release, item, "release_dates", date => Pick(date, "certification"));
                    return release;
                }) };
            }
            return result;
        }

        private JsonObject Media(JsonElement value, string type, bool includeRequests, JsonElement catalog = default)
        {
            var result = Pick(value, "id tmdbId tvdbId mediaType");
            var match = _match(type, catalog.ValueKind == JsonValueKind.Object ? catalog : value);
            var requests = new JsonArray();
            if (includeRequests && Property(value, "requests").ValueKind == JsonValueKind.Array)
                foreach (var request in value.GetProperty("requests").EnumerateArray())
                    if (CanSeeRequest(request)) requests.Add(Request(request));
            result["requests"] = requests;
            // Global Seerr availability cannot establish access to a Jellyfin item.
            result["status"] = match?.Status ?? (requests.Any(r => r?["status"]?.GetValue<int>() == 2) ? 3 : requests.Count > 0 ? 2 : 1);
            if (match?.Playable == true) result["jellyfinMediaId"] = match.ItemId;
            var seasonStates = new Dictionary<int, int>();
            foreach (var request in requests)
            {
                if (request?["seasons"] is not JsonArray seasons) continue;
                var status = request["status"]?.GetValue<int>();
                if (status != 1 && status != 2) continue;
                foreach (var season in seasons)
                {
                    var number = season is JsonValue scalar ? scalar.GetValue<int>() : season?["seasonNumber"]?.GetValue<int>();
                    if (number.HasValue) seasonStates[number.Value] = status == 2 ? 3 : 2;
                }
            }
            if (match is not null)
                foreach (var season in match.EpisodeCounts.Keys) seasonStates[season] = match.SeasonStatus(season);
            result["seasons"] = new JsonArray(seasonStates.OrderBy(entry => entry.Key)
                .Select(entry => (JsonNode)new JsonObject { ["seasonNumber"] = entry.Key, ["status"] = entry.Value }).ToArray());
            if (requests.Count > 0 || match is not null)
                foreach (var key in new[] { "downloadStatus", "downloadStatus4k" }) AddArray(result, value, key, download =>
                {
                    var entry = Pick(download, "estimatedCompletionTime mediaType size sizeLeft status timeLeft");
                    if (download.TryGetProperty("episode", out var episode)) entry["episode"] = Pick(episode, "seasonNumber episodeNumber title airDate runtime overview");
                    return entry;
                });
            return result;
        }

        private bool CanSeeRequest(JsonElement request) => _identity.HasPermission(16 | 16384)
            || Int(Property(request, "requestedBy"), "id") == _identity.Id;

        private JsonObject Request(JsonElement value)
        {
            if (value.ValueKind != JsonValueKind.Object || !value.TryGetProperty("id", out _)) return new JsonObject();
            if (!CanSeeRequest(value)) throw new IntegrationException("permission_denied", 403);
            var result = Pick(value, "id status createdAt updatedAt is4k serverId profileId");
            foreach (var key in new[] { "requestedBy", "modifiedBy" })
                if (value.TryGetProperty(key, out var user)) result[key] = Pick(user, "id username displayName");
            if (value.TryGetProperty("media", out var media)) result["media"] = Media(media, Type(media), false);
            if (Property(value, "seasons").ValueKind == JsonValueKind.Array)
                result["seasons"] = Array(value.GetProperty("seasons"), item => item.ValueKind == JsonValueKind.Number
                    ? JsonValue.Create(item.GetInt32())! : Pick(item, "id seasonNumber"));
            return result;
        }

        private static JsonObject User(JsonElement value, bool self)
        {
            var user = Pick(value, self ? "id username displayName email permissions movieQuotaLimit movieQuotaDays tvQuotaLimit tvQuotaDays" : "id username displayName");
            if (self && value.TryGetProperty("settings", out var settings)) user["settings"] = Pick(settings, "locale discoverRegion originalLanguage");
            return user;
        }

        internal static JsonNode Service(JsonElement value)
        {
            if (value.ValueKind == JsonValueKind.Array) return Array(value, Server);
            var result = new JsonObject();
            if (value.TryGetProperty("server", out var server))
            {
                var projected = Server(server);
                foreach (var key in new[] { "activeDirectory", "activeAnimeDirectory" })
                {
                    var rawPath = Property(server, key);
                    if (rawPath.ValueKind != JsonValueKind.String || Property(value, "rootFolders").ValueKind != JsonValueKind.Array) continue;
                    foreach (var folder in value.GetProperty("rootFolders").EnumerateArray())
                        if (Property(folder, "path").ValueKind == JsonValueKind.String && folder.GetProperty("path").GetString() == rawPath.GetString())
                            projected[key] = "folder:" + Int(folder, "id");
                }
                result["server"] = projected;
            }
            AddArray(result, value, "profiles", item => Pick(item, "id name"));
            AddArray(result, value, "tags", item => Pick(item, "id label"));
            AddArray(result, value, "rootFolders", item => new JsonObject { ["id"] = Int(item, "id"), ["path"] = "folder:" + Int(item, "id") });
            return result;
        }

        private static JsonObject Server(JsonElement value)
        {
            var server = Pick(value, "id name is4k isDefault activeProfileId activeProfileName activeAnimeProfileId activeAnimeProfileName activeLanguageProfileId activeAnimeLanguageProfileId");
            if (Property(value, "activeTags").ValueKind == JsonValueKind.Array)
                server["activeTags"] = Array(value.GetProperty("activeTags"), tag => tag.ValueKind == JsonValueKind.Number ? JsonValue.Create(tag.GetInt32())! : null);
            return server;
        }

        private static JsonObject Rating(JsonElement value) => Pick(value, "title year criticsScore criticsRating audienceScore audienceRating");
        internal static string Type(JsonElement value) => Property(value, "mediaType").ValueKind == JsonValueKind.String
            ? value.GetProperty("mediaType").GetString()! : value.ValueKind == JsonValueKind.Object && value.TryGetProperty("firstAirDate", out _) ? "tv" : "movie";
        internal static int Int(JsonElement value, string key) => Property(value, key).ValueKind == JsonValueKind.Number && value.GetProperty(key).TryGetInt32(out var number) ? number : 0;
        internal static JsonElement Property(JsonElement value, string key) => value.ValueKind == JsonValueKind.Object && value.TryGetProperty(key, out var child) ? child : default;
        internal static JsonObject Pick(JsonElement value, string fields)
        {
            var result = new JsonObject();
            foreach (var field in fields.Split(' ', StringSplitOptions.RemoveEmptyEntries))
            {
                var item = Property(value, field);
                if (item.ValueKind is JsonValueKind.String or JsonValueKind.Number or JsonValueKind.True or JsonValueKind.False or JsonValueKind.Null)
                    result[field] = JsonNode.Parse(item.GetRawText());
            }
            return result;
        }

        private static JsonObject Images(JsonObject result, JsonElement value, string fields)
        {
            foreach (var field in fields.Split(' '))
            {
                var path = Property(value, field);
                if (path.ValueKind == JsonValueKind.String && SeerrOperations.Matches(path.GetString()!, @"^/[a-zA-Z0-9_.-]+$")) result[field] = path.GetString();
            }
            return result;
        }

        private static JsonObject Page(JsonElement value, Func<JsonElement, JsonNode?> project)
        {
            var items = Property(value, "results");
            if (items.ValueKind != JsonValueKind.Array || items.GetArrayLength() > 100) throw new IntegrationException("invalid_response");
            var result = Pick(value, "page totalPages totalResults");
            if (value.TryGetProperty("pageInfo", out var page)) result["pageInfo"] = Pick(page, "pages pageSize results page");
            AddArray(result, value, "results", project);
            return result;
        }

        private static void AddArray(JsonObject result, JsonElement value, string key, Func<JsonElement, JsonNode?> project)
        {
            var items = Property(value, key);
            if (items.ValueKind == JsonValueKind.Array) result[key] = Array(items, project);
        }

        private static JsonArray Array(JsonElement value, Func<JsonElement, JsonNode?> project) => value.ValueKind == JsonValueKind.Array
            ? new JsonArray(value.EnumerateArray().Select(project).Where(item => item is not null).ToArray()) : new JsonArray();
    }
}
