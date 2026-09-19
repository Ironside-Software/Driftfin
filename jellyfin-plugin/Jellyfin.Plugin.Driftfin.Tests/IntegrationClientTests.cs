using System;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.Driftfin.Configuration;
using Xunit;

namespace Jellyfin.Plugin.Driftfin.Tests
{
    public class IntegrationClientTests
    {
        private static PluginConfiguration Config => new()
        {
            SeerrEnabled = true, SeerrUrl = "https://seerr.example/base", SeerrApiKey = "fixture-key",
        };

        [Fact]
        public void ConfigurationChangesCannotRetargetAnInFlightIdentityLookup()
        {
            var saved = Config;
            var request = saved.Snapshot();
            saved.SeerrUrl = "https://different-server.example";
            saved.SeerrApiKey = "different-key";
            Assert.Equal("https://seerr.example/base", request.SeerrUrl);
            Assert.Equal("fixture-key", request.SeerrApiKey);
        }

        [Fact]
        public async Task SearchEnrichmentLoadsOwnershipOnlyForTrackedTitlesWithTheMappedUser()
        {
            var calls = 0;
            using var http = new HttpClient(new Handler(request =>
            {
                calls++;
                Assert.Equal("/base/api/v1/movie/550", request.RequestUri!.AbsolutePath);
                Assert.Equal("42", string.Join("", request.Headers.GetValues("X-API-User")));
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("{\"id\":550,\"mediaInfo\":{\"requests\":[{\"id\":1,\"status\":1,\"requestedBy\":{\"id\":42}}]}}"),
                };
            }));
            var response = JsonSerializer.Deserialize<JsonElement>("""
                {"results":[{"id":550,"mediaType":"movie","mediaInfo":{"id":1,"status":2}},
                  {"id":680,"mediaType":"movie"},{"id":550,"mediaType":"movie","mediaInfo":{"id":1,"status":2}}]}
                """);
            var enriched = await new IntegrationClient(http).EnrichCatalogRequests(Config, response, new SeerrIdentity(42, 32), default);
            Assert.Equal(1, calls);
            Assert.Equal(42, enriched.GetProperty("results")[0].GetProperty("mediaInfo").GetProperty("requests")[0].GetProperty("requestedBy").GetProperty("id").GetInt32());
            Assert.False(response.GetProperty("results")[0].GetProperty("mediaInfo").TryGetProperty("requests", out _));
        }

        [Fact]
        public async Task SendsOnlyServiceCredentialsAndDerivedIdentity()
        {
            using var http = new HttpClient(new Handler(request =>
            {
                Assert.Equal("https://seerr.example/base/api/v1/auth/me", request.RequestUri!.AbsoluteUri);
                Assert.Equal("fixture-key", string.Join("", request.Headers.GetValues("X-Api-Key")));
                Assert.Equal("42", string.Join("", request.Headers.GetValues("X-API-User")));
                Assert.Null(request.Headers.Authorization);
                Assert.False(request.Headers.Contains("Cookie"));
                return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("{\"id\":42}") };
            }));
            var result = await new IntegrationClient(http).SendAsync(Config, IntegrationService.Seerr,
                HttpMethod.Get, "api/v1/auth/me", 42, null, default);
            Assert.Equal(42, result.GetProperty("id").GetInt32());
        }

        [Theory]
        [InlineData(401, "invalid_credentials")]
        [InlineData(403, "permission_denied")]
        [InlineData(429, "rate_limited")]
        [InlineData(302, "upstream_error")]
        [InlineData(500, "upstream_error")]
        public async Task DoesNotExposeUpstreamErrors(int status, string reason)
        {
            using var http = new HttpClient(new Handler(_ => new HttpResponseMessage((HttpStatusCode)status)
            {
                Content = new StringContent("secret-key and internal host"),
            }));
            var error = await Assert.ThrowsAsync<IntegrationException>(() => new IntegrationClient(http).SendAsync(
                Config, IntegrationService.Seerr, HttpMethod.Get, "api/v1/auth/me", 42, null, default));
            Assert.Equal(reason, error.Reason);
            Assert.DoesNotContain("secret", error.ToString());
        }

        [Fact]
        public async Task RejectsOversizedAndMalformedResponses()
        {
            foreach (var payload in new[] { "not JSON", new string('x', IntegrationClient.MaximumResponseBytes + 1) })
            {
                using var http = new HttpClient(new Handler(_ => new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new ByteArrayContent(Encoding.UTF8.GetBytes(payload)),
                }));
                var error = await Assert.ThrowsAsync<IntegrationException>(() => new IntegrationClient(http).SendAsync(
                    Config, IntegrationService.Seerr, HttpMethod.Get, "api/v1/auth/me", 42, null, default));
                Assert.Equal("invalid_response", error.Reason);
            }
        }

        [Theory]
        [InlineData("file:///etc/passwd")]
        [InlineData("https://user:password@host")]
        [InlineData("https://host?apikey=secret")]
        [InlineData("https://host#fragment")]
        public void RejectsCredentialBearingOrNonHttpConfiguration(string url)
        {
            var config = Config;
            config.SeerrUrl = url;
            Assert.Throws<IntegrationException>(() => IntegrationClient.Destination(config, IntegrationService.Seerr));
        }

        [Fact]
        public async Task CancellationPropagatesWithoutRetry()
        {
            using var cancellation = new CancellationTokenSource();
            cancellation.Cancel();
            using var http = new HttpClient(new Handler(_ => throw new OperationCanceledException(cancellation.Token)));
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() => new IntegrationClient(http).SendAsync(
                Config, IntegrationService.Seerr, HttpMethod.Post, "api/v1/request", 42, null, cancellation.Token));
        }

        private sealed class Handler : HttpMessageHandler
        {
            private readonly Func<HttpRequestMessage, HttpResponseMessage> _respond;
            public Handler(Func<HttpRequestMessage, HttpResponseMessage> respond) => _respond = respond;
            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
                => Task.FromResult(_respond(request));
        }
    }
}
