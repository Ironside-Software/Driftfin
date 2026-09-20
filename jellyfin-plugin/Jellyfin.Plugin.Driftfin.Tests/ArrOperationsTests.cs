using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.Driftfin.Api;
using Jellyfin.Plugin.Driftfin.Configuration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Primitives;
using Xunit;

namespace Jellyfin.Plugin.Driftfin.Tests
{
    public class ArrOperationsTests
    {
        private static JsonElement Json(string value) => JsonSerializer.Deserialize<JsonElement>(value);

        [Theory]
        [InlineData("folder:4", 2, true)]
        [InlineData("folder:99", 2, false)]
        [InlineData("folder:4", 99, false)]
        [InlineData("/private/path", 2, false)]
        public async Task AddsUseOnlyApprovedFoldersProfilesAndFreshLookup(string folder, int profile, bool valid)
        {
            var config = new PluginConfiguration { RadarrEnabled = true, RadarrUrl = "https://radarr.test/base", RadarrApiKey = "fixture" };
            using var http = new HttpClient(new Handler());
            var controller = new DriftfinArrController(new IntegrationClient(http));
            var body = JsonSerializer.SerializeToElement(new { tmdbId = 550, title = "Spoofed", id = 900,
                rootFolderPath = folder, qualityProfileId = profile, monitored = true, addOptions = new { searchForMovie = true } });
            if (!valid)
            {
                await Assert.ThrowsAsync<IntegrationException>(() => controller.AddPayload(config, IntegrationService.Radarr, "movie", body, default));
                return;
            }
            var payload = await controller.AddPayload(config, IntegrationService.Radarr, "movie", body, default);
            Assert.Equal("/server/movies", payload.GetProperty("rootFolderPath").GetString());
            Assert.Equal("Actual", payload.GetProperty("title").GetString());
            Assert.False(payload.TryGetProperty("id", out _));
            Assert.True(payload.GetProperty("addOptions").GetProperty("searchForMovie").GetBoolean());
        }

        private sealed class Handler : HttpMessageHandler
        {
            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                Assert.Equal(HttpMethod.Get, request.Method);
                Assert.Equal("fixture", request.Headers.GetValues("X-Api-Key").Single());
                var body = request.RequestUri!.AbsolutePath switch
                {
                    "/base/api/v3/rootfolder" => "[{\"id\":4,\"accessible\":true,\"path\":\"/server/movies\"}]",
                    "/base/api/v3/qualityprofile" => "[{\"id\":2}]",
                    "/base/api/v3/movie/lookup/tmdb" => "{\"id\":0,\"tmdbId\":550,\"title\":\"Actual\"}",
                    _ => throw new Exception("Unexpected operation"),
                };
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(body) });
            }
        }

        [Fact]
        public void AllArrActionsRequireJellyfinElevation()
        {
            var controller = typeof(DriftfinArrController);
            Assert.Equal("RequiresElevation", controller.GetCustomAttribute<AuthorizeAttribute>()?.Policy);
            Assert.DoesNotContain(controller.GetMethods(), method => method.GetCustomAttribute<AllowAnonymousAttribute>() != null);
        }

        [Theory]
        [InlineData("episode", "seriesId", "-1")]
        [InlineData("movie", "tmdbId", "1&apiKey=secret")]
        [InlineData("series/lookup", "term", "https://attacker")]
        [InlineData("calendar", "unmonitored", "false")]
        [InlineData("rootfolder", "path", "/private")]
        public void RejectsUnapprovedQueryValues(string operation, string key, string value)
        {
            Assert.Throws<IntegrationException>(() => ArrOperations.Query(operation,
                new QueryCollection(new Dictionary<string, StringValues> { [key] = value })));
        }

        [Fact]
        public void CalendarRequiresABoundedDateRange()
        {
            var query = new Dictionary<string, StringValues> { ["start"] = "2026-01-01", ["end"] = "2028-01-01" };
            Assert.Throws<IntegrationException>(() => ArrOperations.Query("calendar", new QueryCollection(query)));
            query["end"] = "2026-02-01";
            Assert.Contains("start=2026-01-01", ArrOperations.Query("calendar", new QueryCollection(query)));
        }

        [Theory]
        [InlineData("sonarr", "command", "{\"name\":\"DeleteSeries\",\"episodeIds\":[1]}")]
        [InlineData("radarr", "command", "{\"name\":\"MoviesSearch\",\"movieIds\":[0]}")]
        [InlineData("sonarr", "episode/monitor", "{\"monitored\":false,\"episodeIds\":[1]}")]
        [InlineData("radarr", "command", "{\"name\":\"MoviesSearch\",\"movieIds\":[1],\"path\":\"/private\"}")]
        public void RejectsUnsupportedMutations(string service, string operation, string body)
        {
            Assert.Throws<IntegrationException>(() => ArrOperations.Mutation(service, operation, Json(body)));
        }

        [Fact]
        public void AllowsExistingMonitorAndSearchActions()
        {
            var body = Json("{\"name\":\"MoviesSearch\",\"movieIds\":[1,2]}");
            Assert.Equal(body, ArrOperations.Mutation("radarr", "command", body));
            body = Json("{\"monitored\":true,\"episodeIds\":[3]}");
            Assert.Equal(body, ArrOperations.Mutation("sonarr", "episode/monitor", body));
        }

        [Fact]
        public void ProjectsNestedCalendarMetadataAndOpaqueFolders()
        {
            var projected = ArrOperations.Project("calendar", Json("""
                [{"id":1,"title":"Episode","airDateUtc":"2026-01-01","hasFile":true,
                  "path":"private","episodeFile":{"path":"private"},
                  "series":{"title":"Show","tvdbId":7,"path":"private","apiKey":"private"}}]
                """)).ToJsonString();
            Assert.Contains("Show", projected);
            Assert.DoesNotContain("private", projected);
            var folder = ArrOperations.Project("rootfolder", Json("{\"id\":4,\"accessible\":true,\"path\":\"private\",\"unmappedFolders\":[{\"path\":\"private\"}]}"));
            Assert.Equal("folder:4", folder["path"]!.GetValue<string>());
            Assert.DoesNotContain("private", folder.ToJsonString());
        }
    }
}
