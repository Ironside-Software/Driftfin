using System;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Jellyfin.Plugin.Driftfin.Api
{
    [ApiController]
    [Route("Driftfin/v1/integrations")]
    [Authorize(Policy = "RequiresElevation")]
    public sealed class DriftfinDiagnosticsController : ControllerBase
    {
        private readonly IntegrationClient _client;

        public DriftfinDiagnosticsController(IntegrationClient client) => _client = client;

        [HttpPost("{service}/check")]
        public async Task<ActionResult> Check(string service, CancellationToken cancellationToken)
        {
            var target = service switch
            {
                "seerr" => IntegrationService.Seerr,
                "sonarr" => IntegrationService.Sonarr,
                "radarr" => IntegrationService.Radarr,
                _ => (IntegrationService?)null,
            };
            if (!target.HasValue) return NotFound();
            var config = Plugin.Instance?.Configuration.Snapshot();
            if (config is null) return NotFound();

            var correlationId = Guid.NewGuid().ToString("N");
            string? reason = null;
            try
            {
                // /auth/me checks the Seerr credential; public /status alone cannot.
                await _client.SendAsync(config, target.Value, HttpMethod.Get,
                    target == IntegrationService.Seerr ? "api/v1/auth/me" : "api/v3/system/status",
                    null, null, cancellationToken).ConfigureAwait(false);
            }
            catch (IntegrationException error)
            {
                reason = error.Reason;
            }

            return Ok(new { service, healthy = reason is null, reason, correlationId, checkedAt = DateTimeOffset.UtcNow });
        }
    }
}
