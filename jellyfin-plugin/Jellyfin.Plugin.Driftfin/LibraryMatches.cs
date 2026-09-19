using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using Jellyfin.Data.Enums;
using Jellyfin.Database.Implementations.Entities;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.TV;
using MediaBrowser.Controller.Library;

namespace Jellyfin.Plugin.Driftfin
{
    internal sealed record LibraryMatch(string ItemId, bool Playable, int Status,
        IReadOnlyDictionary<int, int> EpisodeCounts, IReadOnlyDictionary<int, int> ExpectedEpisodes)
    {
        internal int SeasonStatus(int season) => EpisodeCounts.TryGetValue(season, out var count) && count > 0
            ? ExpectedEpisodes.TryGetValue(season, out var expected) && expected > 0 && count >= expected ? 5 : 4 : 1;
    }

    // Lives for one HTTP request only. Library visibility is never cached across users.
    internal sealed class LibraryMatches
    {
        private readonly ILibraryManager _library;
        private readonly User _user;
        private readonly bool _playable;
        private readonly Dictionary<string, LibraryMatch?> _matches = new();

        internal LibraryMatches(ILibraryManager library, User user, bool playable)
        {
            _library = library;
            _user = user;
            _playable = playable;
        }

        internal LibraryMatch? Find(string type, JsonElement catalog)
        {
            if (type != "movie" && type != "tv") return null;
            var ids = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var tmdb = SeerrResponses.Int(catalog, "tmdbId");
            // Catalog IDs are TMDB IDs; a Seerr media database id is not.
            if (tmdb == 0 && (SeerrResponses.Property(catalog, "title").ValueKind == JsonValueKind.String
                || SeerrResponses.Property(catalog, "name").ValueKind == JsonValueKind.String)) tmdb = SeerrResponses.Int(catalog, "id");
            if (tmdb > 0) ids["Tmdb"] = tmdb.ToString(CultureInfo.InvariantCulture);
            var external = SeerrResponses.Property(catalog, "externalIds");
            var tvdb = SeerrResponses.Int(external, "tvdbId");
            if (tvdb == 0) tvdb = SeerrResponses.Int(catalog, "tvdbId");
            if (tvdb > 0) ids["Tvdb"] = tvdb.ToString(CultureInfo.InvariantCulture);
            var imdb = SeerrResponses.Property(external, "imdbId");
            if (imdb.ValueKind == JsonValueKind.String && SeerrOperations.Matches(imdb.GetString()!, "^tt[0-9]+$")) ids["Imdb"] = imdb.GetString()!;
            if (ids.Count == 0) return null;
            var key = type + ":" + string.Join("|", ids.Select(id => id.Key + "=" + id.Value)) + ":" + SeerrResponses.Int(catalog, "numberOfEpisodes");
            if (_matches.TryGetValue(key, out var cached)) return cached;
            var candidates = _library.GetItemList(new InternalItemsQuery(_user)
            {
                Recursive = true,
                IncludeItemTypes = new[] { type == "movie" ? BaseItemKind.Movie : BaseItemKind.Series },
                HasAnyProviderId = ids,
                IsVirtualItem = false,
                IsMissing = false,
                Limit = 20,
            }, false);
            var item = candidates.FirstOrDefault(candidate => ids.All(id => !candidate.ProviderIds.TryGetValue(id.Key, out var stored)
                    || string.Equals(stored, id.Value, StringComparison.OrdinalIgnoreCase))
                && _library.GetItemById<BaseItem>(candidate.Id, _user) is not null);
            if (item is null) return _matches[key] = null;

            var counts = new Dictionary<int, int>();
            var expected = new Dictionary<int, int>();
            var status = 5;
            if (type == "tv")
            {
                var episodes = _library.GetItemList(new InternalItemsQuery(_user)
                {
                    Recursive = true, AncestorIds = new[] { item.Id }, IncludeItemTypes = new[] { BaseItemKind.Episode },
                    IsVirtualItem = false, IsMissing = false, IsPlaceHolder = false,
                }, false).OfType<Episode>();
                foreach (var group in episodes.GroupBy(episode => episode.ParentIndexNumber ?? 0))
                    counts[group.Key] = group.SelectMany(EpisodeNumbers).Distinct().Count();
                var seasons = SeerrResponses.Property(catalog, "seasons");
                if (seasons.ValueKind == JsonValueKind.Array)
                    foreach (var season in seasons.EnumerateArray()) expected[SeerrResponses.Int(season, "seasonNumber")] = SeerrResponses.Int(season, "episodeCount");
                var total = SeerrResponses.Int(catalog, "numberOfEpisodes");
                var upstreamStatus = SeerrResponses.Int(SeerrResponses.Property(catalog, "mediaInfo"), "status");
                if (upstreamStatus == 0) upstreamStatus = SeerrResponses.Int(catalog, "status");
                status = total > 0 ? counts.Where(pair => pair.Key > 0).Sum(pair => pair.Value) >= total ? 5 : 4
                    : upstreamStatus == 5 ? 5 : 4;
                if (counts.Values.Sum() == 0) return _matches[key] = null;
            }
            return _matches[key] = new LibraryMatch(item.Id.ToString("N"), _playable, status, counts, expected);
        }

        private static IEnumerable<int> EpisodeNumbers(Episode episode)
        {
            if (episode.IndexNumber is not int start || start < 0) return Array.Empty<int>();
            var end = episode.IndexNumberEnd ?? start;
            // Treat malformed ranges as one episode, never an enormous allocation
            // or a false claim that every episode is available.
            var count = (long)end - start + 1;
            return Enumerable.Range(start, count is > 0 and <= 1000 ? (int)count : 1);
        }
    }
}
