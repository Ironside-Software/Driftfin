using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Http;

namespace Jellyfin.Plugin.Driftfin
{
    internal static class ArrOperations
    {
        internal static string Query(string operation, IQueryCollection query)
        {
            var allowed = operation switch
            {
                "calendar" => new[] { "start", "end", "includeSeries", "unmonitored" },
                "episode" => new[] { "seriesId" },
                "movie" or "movie/lookup/tmdb" => new[] { "tmdbId" },
                "series/lookup" => new[] { "term" },
                _ => Array.Empty<string>(),
            };
            if (query.Any(pair => !allowed.Contains(pair.Key) || pair.Value.Count != 1)) Invalid();
            var values = new Dictionary<string, string>();
            foreach (var pair in query)
            {
                var value = pair.Value.ToString();
                if (pair.Key is "seriesId" or "tmdbId") Positive(value);
                if (pair.Key == "term")
                {
                    if (!value.StartsWith("tvdb:", StringComparison.Ordinal)) Invalid();
                    Positive(value[5..]);
                }
                if (pair.Key is "includeSeries" or "unmonitored" && value != "true") Invalid();
                values[pair.Key] = value;
            }
            if (operation == "calendar")
            {
                if (!values.TryGetValue("start", out var start) || !values.TryGetValue("end", out var end)
                    || !DateTimeOffset.TryParse(start, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var from)
                    || !DateTimeOffset.TryParse(end, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var to)
                    || to < from || to - from > TimeSpan.FromDays(366)) Invalid();
            }
            if (operation == "episode" && !values.ContainsKey("seriesId")
                || operation == "movie/lookup/tmdb" && !values.ContainsKey("tmdbId")
                || operation == "series/lookup" && !values.ContainsKey("term")) Invalid();
            return values.Count == 0 ? "" : "?" + string.Join("&", values.Select(pair =>
                Uri.EscapeDataString(pair.Key) + "=" + Uri.EscapeDataString(pair.Value)));
        }

        internal static JsonElement Mutation(string service, string operation, JsonElement body)
        {
            if (body.ValueKind != JsonValueKind.Object) Invalid();
            var idsKey = service == "sonarr" ? "episodeIds" : "movieIds";
            var fields = operation == "episode/monitor" ? new[] { "episodeIds", "monitored" } : new[] { "name", idsKey };
            if (body.EnumerateObject().Any(property => !fields.Contains(property.Name))
                || body.EnumerateObject().Select(property => property.Name).Distinct().Count() != body.EnumerateObject().Count()) Invalid();
            if (operation == "episode/monitor")
            {
                if (SeerrResponses.Property(body, "monitored").ValueKind != JsonValueKind.True) Invalid();
            }
            else
            {
                var name = SeerrResponses.Property(body, "name");
                if (name.ValueKind != JsonValueKind.String || name.GetString() != (service == "sonarr" ? "EpisodeSearch" : "MoviesSearch")) Invalid();
            }
            var ids = SeerrResponses.Property(body, idsKey);
            if (ids.ValueKind != JsonValueKind.Array || ids.GetArrayLength() is < 1 or > 100) Invalid();
            foreach (var id in ids.EnumerateArray())
                if (id.ValueKind != JsonValueKind.Number || !id.TryGetInt32(out var number) || number <= 0) Invalid();
            return body;
        }

        internal static JsonNode Project(string operation, JsonElement value)
        {
            if (value.ValueKind == JsonValueKind.Array)
            {
                if (value.GetArrayLength() > 10000) throw new IntegrationException("invalid_response");
                return new JsonArray(value.EnumerateArray().Select(item => (JsonNode?)Project(operation, item)).ToArray());
            }
            if (value.ValueKind != JsonValueKind.Object) throw new IntegrationException("invalid_response");
            if (operation == "rootfolder")
            {
                var folder = SeerrResponses.Pick(value, "id accessible");
                var id = SeerrResponses.Int(value, "id");
                if (id <= 0) throw new IntegrationException("invalid_response");
                folder["path"] = $"folder:{id}";
                return folder;
            }
            if (operation == "qualityprofile") return SeerrResponses.Pick(value, "id name");
            var result = SeerrResponses.Pick(value,
                "id tvdbId tmdbId title titleSlug seasonNumber episodeNumber airDateUtc digitalRelease physicalRelease inCinemas hasFile monitored");
            var series = SeerrResponses.Property(value, "series");
            if (series.ValueKind == JsonValueKind.Object) result["series"] = SeerrResponses.Pick(series, "title tvdbId");
            return result;
        }

        internal static int Positive(string value)
        {
            if (!int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var number) || number <= 0) Invalid();
            return number;
        }

        internal static void Invalid() => throw new IntegrationException("invalid_request", 400);
    }
}
