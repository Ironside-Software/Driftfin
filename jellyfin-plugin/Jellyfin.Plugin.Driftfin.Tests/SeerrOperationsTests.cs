using System;
using System.Collections.Generic;
using System.Text.Json;
using Jellyfin.Plugin.Driftfin.Api;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Primitives;
using Xunit;

namespace Jellyfin.Plugin.Driftfin.Tests
{
    public class SeerrOperationsTests
    {
        private static readonly SeerrIdentity Member = new(42, 32);
        private static JsonElement Json(string value) => JsonSerializer.Deserialize<JsonElement>(value);

        [Theory]
        [InlineData("GET", "settings/main")]
        [InlineData("POST", "auth/local")]
        [InlineData("POST", "auth/jellyfin")]
        [InlineData("GET", "imageproxy/https://attacker")]
        [InlineData("GET", "movie/../../settings")]
        [InlineData("PUT", "request/1")]
        public void UnknownOperationsAreNotProxied(string method, string path)
        {
            var error = Assert.Throws<IntegrationException>(() => SeerrOperations.Validate(method, path, QueryCollection.Empty, Member));
            Assert.Equal(404, error.Status);
        }

        [Theory]
        [InlineData("take", "101")]
        [InlineData("skip", "-1")]
        [InlineData("userId", "1")]
        [InlineData("requestedBy", "1")]
        public void BoundsPaginationAndIdentityFilters(string key, string value)
        {
            Assert.Throws<IntegrationException>(() => SeerrOperations.Validate("GET", "request",
                new QueryCollection(new Dictionary<string, StringValues> { [key] = value }), Member));
        }

        [Fact]
        public void SearchQueryIsEncodedAsData()
        {
            var path = SeerrOperations.Validate("GET", "search",
                new QueryCollection(new Dictionary<string, StringValues> { ["query"] = "a &requestedBy=1? 🎬" }), Member);
            Assert.Equal("api/v1/search?query=a%20%26requestedBy%3D1%3F%20%F0%9F%8E%AC", path);
        }

        [Theory]
        [InlineData("GET", "user/1/quota")]
        [InlineData("GET", "user/1/requests")]
        [InlineData("GET", "user")]
        [InlineData("GET", "media")]
        [InlineData("POST", "request/7/approve")]
        [InlineData("DELETE", "media/7/file")]
        public void MemberCannotReadOtherUsersOrManageMedia(string method, string path)
        {
            var error = Assert.Throws<IntegrationException>(() => SeerrOperations.Validate(method, path, QueryCollection.Empty, Member));
            Assert.Equal(403, error.Status);
        }

        [Fact]
        public void RequestIdentityCannotBeOverriddenEvenByManager()
        {
            var manager = new SeerrIdentity(42, 2);
            Assert.Throws<IntegrationException>(() => SeerrOperations.RequestBody(Json("{\"mediaType\":\"movie\",\"mediaId\":1,\"userId\":1}"), manager));
            var body = SeerrOperations.RequestBody(Json("{\"mediaType\":\"movie\",\"mediaId\":1,\"userId\":42}"), manager);
            Assert.False(body.ContainsKey("userId"));
        }

        [Theory]
        [InlineData("{\"mediaType\":\"movie\",\"mediaId\":1,\"requestedBy\":1}")]
        [InlineData("{\"mediaType\":\"movie\",\"mediaId\":1,\"is4k\":true}")]
        [InlineData("{\"mediaType\":\"movie\",\"mediaId\":1,\"rootFolder\":\"/etc\"}")]
        [InlineData("{\"mediaType\":\"tv\",\"mediaId\":1,\"seasons\":[-1]}")]
        [InlineData("{\"mediaType\":\"movie\",\"mediaId\":\"1\"}")]
        [InlineData("{\"mediaType\":\"movie\",\"mediaId\":1,\"mediaId\":2}")]
        public void ValidatesRequestShapeAndRights(string body) => Assert.Throws<IntegrationException>(() => SeerrOperations.RequestBody(Json(body), Member));

        [Fact]
        public void PreservesFourKOnlyRequestPermissions()
        {
            var user = new SeerrIdentity(42, 2048);
            SeerrOperations.RequestBody(Json("{\"mediaType\":\"movie\",\"mediaId\":1,\"is4k\":true}"), user);
            Assert.Throws<IntegrationException>(() => SeerrOperations.RequestBody(Json("{\"mediaType\":\"movie\",\"mediaId\":1}"), user));
        }

        [Fact]
        public void FolderAliasesResolveOnlyAgainstSavedServiceOptions()
        {
            var options = Json("{\"profiles\":[{\"id\":2}],\"tags\":[{\"id\":3}],\"rootFolders\":[{\"id\":4,\"path\":\"/media/movies\"}]}");
            var body = SeerrOperations.RequestBody(Json("{\"mediaType\":\"movie\",\"mediaId\":1,\"profileId\":2,\"tags\":[3],\"rootFolder\":\"folder:4\"}"), Member);
            DriftfinSeerrController.ResolveRequestOptions(body, options);
            Assert.Equal("/media/movies", body["rootFolder"]!.GetValue<string>());
            body["rootFolder"] = "folder:999";
            Assert.Throws<IntegrationException>(() => DriftfinSeerrController.ResolveRequestOptions(body, options));
            body.Remove("rootFolder");
            body["profileId"] = 999;
            Assert.Throws<IntegrationException>(() => DriftfinSeerrController.ResolveRequestOptions(body, options));
        }
    }
}
