using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Nodes;
using Xunit;

namespace Jellyfin.Plugin.Driftfin.Tests
{
    public class SeerrResponsesTests
    {
        private static JsonElement Json(string value) => JsonSerializer.Deserialize<JsonElement>(value);
        private static SeerrResponses Member => new(new SeerrIdentity(42, 32), (_, _) => null);

        [Fact]
        public void ProjectsUserWithoutNestedCredentials()
        {
            var user = Member.Project("auth/me", Json("""
                {"id":42,"username":"member","permissions":32,"apiKey":"secret","plexToken":"secret",
                 "jellyfinAuthToken":"secret","avatar":"http://internal/avatar?token=secret",
                 "settings":{"locale":"en","apiKey":"secret","nested":{"permissions":2}}}
                """));
            Assert.Equal("member", user["username"]!.GetValue<string>());
            Assert.Equal("en", user["settings"]!["locale"]!.GetValue<string>());
            Assert.DoesNotContain("secret", user.ToJsonString());
            Assert.Null(user["avatar"]);
        }

        [Fact]
        public void HiddenLibraryAndOtherUsersRequestsDoNotLeak()
        {
            var result = Member.Project("movie/1", Json("""
                {"id":1,"title":"Movie","posterPath":"/poster.jpg","apiKey":"secret",
                 "mediaInfo":{"id":10,"tmdbId":1,"status":5,"jellyfinMediaId":"hidden-id","serviceUrl":"http://internal",
                   "requests":[{"id":8,"status":2,"requestedBy":{"id":99}}],
                   "downloadStatus":[{"title":"private-file.mkv","downloadId":"private"}]}}
                """));
            var info = result["mediaInfo"]!;
            Assert.Equal(1, info["status"]!.GetValue<int>());
            Assert.Empty(info["requests"]!.AsArray());
            Assert.Null(info["jellyfinMediaId"]);
            Assert.Null(info["downloadStatus"]);
            Assert.DoesNotContain("secret", result.ToJsonString());
            Assert.DoesNotContain("hidden-id", result.ToJsonString());
        }

        [Fact]
        public void OwnPendingRequestIsVisibleWithoutLeakingOtherUsers()
        {
            var result = Member.Project("movie/1", Json("""
                {"id":1,"title":"Movie","mediaInfo":{"status":5,"requests":[
                  {"id":8,"status":1,"requestedBy":{"id":42,"username":"member","plexToken":"secret"}},
                  {"id":9,"status":2,"requestedBy":{"id":99}}]}}
                """));
            Assert.Equal(2, result["mediaInfo"]!["status"]!.GetValue<int>());
            Assert.Single(result["mediaInfo"]!["requests"]!.AsArray());
            Assert.DoesNotContain("secret", result.ToJsonString());
        }

        [Fact]
        public void SeasonRequestsAreScopedToVisibleRequests()
        {
            var result = Member.Project("tv/1", Json("""
                {"id":1,"name":"Show","mediaInfo":{"status":3,"seasons":[{"seasonNumber":2,"status":3}],"requests":[
                  {"id":8,"status":1,"seasons":[{"seasonNumber":1}],"requestedBy":{"id":42}},
                  {"id":9,"status":2,"seasons":[{"seasonNumber":2}],"requestedBy":{"id":99}}]}}
                """));
            var season = Assert.Single(result["mediaInfo"]!["seasons"]!.AsArray());
            Assert.Equal(1, season!["seasonNumber"]!.GetValue<int>());
            Assert.Equal(2, season["status"]!.GetValue<int>());
        }

        [Fact]
        public void AccessibleLibraryMatchControlsAvailabilityAndPlayback()
        {
            var match = new LibraryMatch("accessible", false, 4, new Dictionary<int, int> { [1] = 5 }, new Dictionary<int, int> { [1] = 10 });
            var projection = new SeerrResponses(new SeerrIdentity(42, 32), (_, _) => match);
            var result = projection.Project("tv/1", Json("{\"id\":1,\"name\":\"Show\",\"mediaInfo\":{\"status\":5,\"jellyfinMediaId\":\"hidden\",\"seasons\":[{\"seasonNumber\":1,\"status\":5}]}}"));
            Assert.Equal(4, result["mediaInfo"]!["status"]!.GetValue<int>());
            Assert.Equal(4, result["mediaInfo"]!["seasons"]![0]!["status"]!.GetValue<int>());
            Assert.Null(result["mediaInfo"]!["jellyfinMediaId"]);
            Assert.DoesNotContain("hidden", result.ToJsonString());
        }

        [Fact]
        public void ServiceDetailsUseFolderIdsAndDropSecretsAtEveryLevel()
        {
            var result = SeerrResponses.Service(Json("""
                {"server":{"id":0,"name":"Movies","apiKey":"secret","hostname":"private-host",
                  "activeDirectory":"/private/movies","activeProfileId":2},
                 "profiles":[{"id":2,"name":"HD","apiKey":"secret"}],
                 "tags":[{"id":3,"label":"Movie","nested":{"apiKey":"secret"}}],
                 "rootFolders":[{"id":4,"path":"/private/movies","freeSpace":123,"apiKey":"secret"}]}
                """));
            Assert.Equal("folder:4", result["server"]!["activeDirectory"]!.GetValue<string>());
            Assert.Equal("folder:4", result["rootFolders"]![0]!["path"]!.GetValue<string>());
            Assert.DoesNotContain("private", result.ToJsonString());
            Assert.DoesNotContain("secret", result.ToJsonString());
        }

        [Fact]
        public void MetadataKeepsNestedDisplayFieldsButNotUnknownObjects()
        {
            var result = Member.Project("tv/1", Json("""
                {"id":1,"name":"Show","posterPath":"http://internal/secret","backdropPath":"/valid.jpg",
                 "credits":{"cast":[{"id":2,"name":"Actor","apiKey":"secret","profilePath":"/actor.jpg"}]},
                 "episodes":[{"id":3,"name":"Pilot","episodeNumber":1,"stillPath":"/episode.jpg","nested":{"id":"secret"}}],
                 "contentRatings":{"results":[{"iso_3166_1":"US","rating":"TV-PG","apiKey":"secret"}]},
                 "relatedVideos":[{"site":"YouTube","key":"trailer","url":"http://internal/secret"}]}
                """));
            Assert.Null(result["posterPath"]);
            Assert.Equal("Actor", result["credits"]!["cast"]![0]!["name"]!.GetValue<string>());
            Assert.Equal(1, result["episodes"]![0]!["episodeNumber"]!.GetValue<int>());
            Assert.Equal("TV-PG", result["contentRatings"]![0]!["rating"]!.GetValue<string>());
            Assert.DoesNotContain("secret", result.ToJsonString());
        }

        [Fact]
        public void DiscoveryReturnsOwnedRequestedAndRequestableTitlesWithoutInventingLibraryIds()
        {
            var projection = new SeerrResponses(new SeerrIdentity(42, 32), (_, item) => SeerrResponses.Int(item, "id") == 1
                ? new LibraryMatch("real-library-item", true, 5, new Dictionary<int, int>(), new Dictionary<int, int>()) : null);
            var result = projection.Discovery(Json("""
                {"page":2,"totalPages":5,"totalResults":100,"results":[
                  {"id":1,"mediaType":"movie","title":"Owned"},
                  {"id":2,"mediaType":"movie","title":"Requestable"},
                  {"id":3,"mediaType":"movie","title":"Pending","mediaInfo":{"requests":[{"id":7,"status":1,"requestedBy":{"id":42}}]}},
                  {"id":4,"mediaType":"person","name":"Actor"}]}
                """));
            var cards = result["results"]!.AsArray();
            Assert.Equal(3, cards.Count);
            Assert.Equal("available", cards[0]!["availability"]!.GetValue<string>());
            Assert.Equal("real-library-item", cards[0]!["libraryItemId"]!.GetValue<string>());
            Assert.True(cards[0]!["canPlay"]!.GetValue<bool>());
            Assert.Equal("requestable", cards[1]!["availability"]!.GetValue<string>());
            Assert.Null(cards[1]!["libraryItemId"]);
            Assert.True(cards[1]!["canRequest"]!.GetValue<bool>());
            Assert.Equal("requested", cards[2]!["availability"]!.GetValue<string>());
            Assert.False(cards[2]!["canRequest"]!.GetValue<bool>());
            Assert.Equal(2, result["page"]!.GetValue<int>());
            Assert.Null(result["totalResults"]);
        }
    }
}
