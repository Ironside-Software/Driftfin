using System;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.Driftfin.Configuration;
using MediaBrowser.Controller;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Net;
using MediaBrowser.Model.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Jellyfin.Plugin.Driftfin.Api
{
    [ApiController]
    [Route("Driftfin/v1/capabilities")]
    [Authorize]
    public sealed class DriftfinCapabilitiesController : ControllerBase
    {
        private readonly IAuthorizationContext _auth;
        private readonly IUserManager _users;
        private readonly IServerApplicationHost _host;
        private readonly IntegrationClient _client;

        public DriftfinCapabilitiesController(IAuthorizationContext auth, IUserManager users,
            IServerApplicationHost host, IntegrationClient client)
        {
            _auth = auth;
            _users = users;
            _host = host;
            _client = client;
        }

        [HttpGet]
        public async Task<ActionResult> Get(CancellationToken cancellationToken)
        {
            var auth = await _auth.GetAuthorizationInfo(Request).ConfigureAwait(false);
            if (auth.UserId == Guid.Empty) return Unauthorized();
            var user = _users.GetUserById(auth.UserId);
            if (user is null) return Unauthorized();
            var policy = _users.GetUserDto(user).Policy;
            if (policy is null || policy.IsDisabled) return Forbid();
            var config = Plugin.Instance?.Configuration;
            if (config is null) return NotFound();

            SeerrIdentity? identity = null;
            var seerrReason = ConfigurationReason(config, IntegrationService.Seerr);
            if (seerrReason is null)
            {
                try
                {
                    identity = await _client.ResolveSeerrIdentity(config, _host.SystemId, auth.UserId, cancellationToken)
                        .ConfigureAwait(false);
                }
                catch (IntegrationException error)
                {
                    seerrReason = error.Reason;
                }
            }

            var contentReason = AllowsExternalCatalog(policy) ? null : "content_restricted";
            var catalogReason = contentReason ?? seerrReason;
            var canRequest = identity?.HasPermission(32 | 262144 | 524288) == true;
            var canManageRequests = identity?.HasPermission(16) == true;
            return Ok(new
            {
                protocolVersion = 1,
                pluginVersion = typeof(Plugin).Assembly.GetName().Version?.ToString(),
                features = new
                {
                    discovery = Feature(catalogReason is null, catalogReason),
                    requests = Feature(catalogReason is null && canRequest,
                        catalogReason ?? (canRequest ? null : "permission_denied")),
                    requestManagement = Feature(catalogReason is null && canManageRequests,
                        catalogReason ?? (canManageRequests ? null : "permission_denied")),
                    arrManagement = Feature(policy.IsAdministrator, policy.IsAdministrator ? null : "permission_denied"),
                    diagnostics = Feature(policy.IsAdministrator, policy.IsAdministrator ? null : "permission_denied"),
                },
                integrations = new
                {
                    seerr = State(config.SeerrEnabled, seerrReason, identity is not null),
                    sonarr = State(config.SonarrEnabled, ConfigurationReason(config, IntegrationService.Sonarr), null),
                    radarr = State(config.RadarrEnabled, ConfigurationReason(config, IntegrationService.Radarr), null),
                },
                migration = new { legacyCredentials = "retired", trakt = config.TraktEnabled ? "manual_setup_required" : null },
            });
        }

        internal static bool AllowsExternalCatalog(UserPolicy policy) => !policy.IsDisabled
            && policy.MaxParentalRating is null && policy.MaxParentalSubRating is null
            && policy.BlockedTags.Length == 0 && policy.AllowedTags.Length == 0
            && policy.BlockUnratedItems.Length == 0 && policy.EnableAllFolders
            && (policy.BlockedMediaFolders?.Length ?? 0) == 0 && policy.AccessSchedules.Length == 0;

        private static object Feature(bool allowed, string? reason) => new { supported = true, allowed, reason };

        private static object State(bool enabled, string? reason, bool? healthy) => new
        {
            configured = enabled && reason != "not_configured" && reason != "invalid_configuration",
            healthy,
            reason,
        };

        private static string? ConfigurationReason(PluginConfiguration config, IntegrationService service)
        {
            try
            {
                IntegrationClient.Destination(config, service);
                return null;
            }
            catch (IntegrationException error)
            {
                return error.Reason;
            }
        }
    }
}
