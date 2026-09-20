using System;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.Driftfin.Api;
using Jellyfin.Plugin.Driftfin.Configuration;
using MediaBrowser.Model.Users;
using Xunit;

namespace Jellyfin.Plugin.Driftfin.Tests
{
    public class SeerrIdentityTests
    {
        private static readonly Guid UserId = Guid.Parse("87ab6670-e671-4595-a771-bd1f5a8de22c");
        private static readonly PluginConfiguration Config = new()
        {
            SeerrEnabled = true, SeerrUrl = "https://seerr.example", SeerrApiKey = "fixture-key",
        };

        [Fact]
        public async Task UsesExactJellyfinIdentityAndDoesNotGrantOwnerRights()
        {
            using var http = new HttpClient(new Fixture());
            var identity = await new IntegrationClient(http).ResolveSeerrIdentity(Config, "server-one", UserId, default);
            Assert.Equal(42, identity.Id);
            Assert.True(identity.HasPermission(32));
            Assert.False(identity.HasPermission(16));
        }

        [Theory]
        [InlineData("wrong-server", "3.4.1", "normal", "server_not_linked")]
        [InlineData("server-one", "9.0.0", "normal", "unsupported_version")]
        [InlineData("server-one", "3.4.1", "missing", "user_not_linked")]
        [InlineData("server-one", "3.4.1", "duplicate", "user_not_linked")]
        [InlineData("server-one", "3.4.1", "owner", "unsupported_version")]
        public async Task FailsClosedOnUnverifiedAttribution(string server, string version, string scenario, string reason)
        {
            var handler = new Fixture(version, scenario);
            using var http = new HttpClient(handler);
            var error = await Assert.ThrowsAsync<IntegrationException>(() =>
                new IntegrationClient(http).ResolveSeerrIdentity(Config, server, UserId, default));
            Assert.Equal(reason, error.Reason);
            Assert.False(handler.OwnerContextUsedForMe);
        }

        [Fact]
        public async Task CannotSubmitRequestsWithoutMappedIdentity()
        {
            using var http = new HttpClient(new Fixture());
            var error = await Assert.ThrowsAsync<IntegrationException>(() => new IntegrationClient(http).SendAsync(
                Config, IntegrationService.Seerr, HttpMethod.Post, "api/v1/request", null, null, default));
            Assert.Equal("user_not_linked", error.Reason);
        }

        [Fact]
        public void RestrictedCatalogPoliciesFailClosed()
        {
            Assert.True(DriftfinCapabilitiesController.AllowsExternalCatalog(new UserPolicy()));
            foreach (var policy in new[]
            {
                new UserPolicy { MaxParentalRating = 10 },
                new UserPolicy { MaxParentalSubRating = 1 },
                new UserPolicy { AllowedTags = new[] { "children" } },
                new UserPolicy { BlockedTags = new[] { "adults" } },
                new UserPolicy { EnableAllFolders = false },
                new UserPolicy { BlockedMediaFolders = new[] { Guid.NewGuid() } },
                new UserPolicy { IsDisabled = true },
            }) Assert.False(DriftfinCapabilitiesController.AllowsExternalCatalog(policy));
        }

        private sealed class Fixture : HttpMessageHandler
        {
            private readonly string _version;
            private readonly string _scenario;
            internal bool OwnerContextUsedForMe { get; private set; }
            internal Fixture(string version = "3.4.1", string scenario = "normal")
            {
                _version = version;
                _scenario = scenario;
            }

            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
            {
                object body;
                switch (request.RequestUri!.AbsolutePath)
                {
                    case "/api/v1/status": body = new { version = _version }; break;
                    case "/api/v1/settings/jellyfin": body = new { serverId = "server-one", apiKey = "never-return-this" }; break;
                    case "/api/v1/user":
                        var match = new { id = 42, jellyfinUserId = UserId.ToString("N") };
                        body = new { results = _scenario switch
                        {
                            "missing" => Array.Empty<object>(),
                            "duplicate" => new object[] { match, match },
                            _ => new object[] { new { id = 1, username = UserId.ToString(), jellyfinUserId = "other-user" }, match },
                        } };
                        break;
                    case "/api/v1/auth/me":
                        OwnerContextUsedForMe = !request.Headers.Contains("X-API-User");
                        Assert.Equal("42", string.Join("", request.Headers.GetValues("X-API-User")));
                        body = new { id = _scenario == "owner" ? 1 : 42, permissions = 32 };
                        break;
                    default: throw new InvalidOperationException("Unexpected upstream operation");
                }

                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(JsonSerializer.Serialize(body)),
                });
            }
        }
    }
}
