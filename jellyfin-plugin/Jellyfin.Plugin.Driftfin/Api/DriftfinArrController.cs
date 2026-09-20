using System;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.Driftfin.Configuration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Jellyfin.Plugin.Driftfin.Api
{
    [ApiController]
    [Route("Driftfin/v1/{service:regex(^(sonarr|radarr)$)}")]
    [Authorize(Policy = "RequiresElevation")]
    [RequestSizeLimit(16384)]
    public sealed class DriftfinArrController : ControllerBase
    {
        private readonly IntegrationClient _client;
        public DriftfinArrController(IntegrationClient client) => _client = client;

        [HttpGet("series")]
        [HttpGet("series/lookup")]
        [HttpGet("episode")]
        [HttpGet("movie")]
        [HttpGet("movie/lookup/tmdb")]
        [HttpGet("calendar")]
        [HttpGet("rootfolder")]
        [HttpGet("qualityprofile")]
        public Task<ActionResult> Read(string service, CancellationToken cancellationToken) => Execute(service, default, cancellationToken);

        [HttpPut("episode/monitor")]
        [HttpPost("command")]
        [HttpPost("movie")]
        [HttpPost("series")]
        public Task<ActionResult> Write(string service, [FromBody] JsonElement body, CancellationToken cancellationToken) => Execute(service, body, cancellationToken);

        private async Task<ActionResult> Execute(string service, JsonElement body, CancellationToken cancellationToken)
        {
            var config = Plugin.Instance?.Configuration.Snapshot();
            if (config is null) return NotFound();
            var target = service == "sonarr" ? IntegrationService.Sonarr : IntegrationService.Radarr;
            var prefix = $"/Driftfin/v1/{service}/";
            var path = Request.Path.Value ?? "";
            if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return NotFound();
            var operation = path[prefix.Length..];
            if (service == "sonarr" && operation.StartsWith("movie", StringComparison.Ordinal)
                || service == "radarr" && (operation.StartsWith("series", StringComparison.Ordinal) || operation.StartsWith("episode", StringComparison.Ordinal))) return NotFound();
            try
            {
                var query = ArrOperations.Query(operation, Request.Query);
                var method = new HttpMethod(Request.Method);
                JsonElement? payload = null;
                if (method != HttpMethod.Get)
                {
                    if (Request.Query.Count != 0) ArrOperations.Invalid();
                    payload = operation is "series" or "movie"
                        ? await AddPayload(config, target, operation, body, cancellationToken).ConfigureAwait(false)
                        : ArrOperations.Mutation(service, operation, body);
                }
                var response = await _client.SendAsync(config, target, method, "api/v3/" + operation + query,
                    null, payload, cancellationToken).ConfigureAwait(false);
                return Ok(ArrOperations.Project(operation, response));
            }
            catch (IntegrationException error)
            {
                return StatusCode(error.Status, new { reason = error.Reason, correlationId = Guid.NewGuid().ToString("N") });
            }
            catch (Exception error) when (error is InvalidOperationException or FormatException or JsonException)
            {
                return BadRequest(new { reason = "invalid_request" });
            }
        }

        internal async Task<JsonElement> AddPayload(PluginConfiguration config, IntegrationService service,
            string operation, JsonElement body, CancellationToken cancellationToken)
        {
            var fields = new[] { "id", "tvdbId", "tmdbId", "title", "titleSlug", "monitored", "seasonFolder", "rootFolderPath", "qualityProfileId", "addOptions" };
            if (body.ValueKind != JsonValueKind.Object
                || body.EnumerateObject().Any(property => !fields.Contains(property.Name))
                || body.EnumerateObject().Select(property => property.Name).Distinct().Count() != body.EnumerateObject().Count()) ArrOperations.Invalid();
            var idKey = operation == "series" ? "tvdbId" : "tmdbId";
            var options = operation == "series"
                ? new JsonObject { ["monitor"] = "none", ["searchForMissingEpisodes"] = false, ["searchForCutoffUnmetEpisodes"] = false }
                : new JsonObject { ["searchForMovie"] = true };
            if (SeerrResponses.Property(body, "monitored").ValueKind != JsonValueKind.True
                || operation == "series" && SeerrResponses.Property(body, "seasonFolder").ValueKind != JsonValueKind.True
                || !JsonElement.DeepEquals(SeerrResponses.Property(body, "addOptions"), JsonSerializer.SerializeToElement(options))) ArrOperations.Invalid();
            var id = SeerrResponses.Int(body, idKey);
            var profileId = SeerrResponses.Int(body, "qualityProfileId");
            var folder = SeerrResponses.Property(body, "rootFolderPath").GetString() ?? "";
            if (id <= 0 || profileId <= 0 || !folder.StartsWith("folder:", StringComparison.Ordinal)) ArrOperations.Invalid();
            var folderId = ArrOperations.Positive(folder[7..]);
            var roots = await _client.SendAsync(config, service, HttpMethod.Get, "api/v3/rootfolder", null, null, cancellationToken).ConfigureAwait(false);
            var root = roots.EnumerateArray().FirstOrDefault(item => SeerrResponses.Int(item, "id") == folderId
                && SeerrResponses.Property(item, "accessible").ValueKind == JsonValueKind.True);
            var profiles = await _client.SendAsync(config, service, HttpMethod.Get, "api/v3/qualityprofile", null, null, cancellationToken).ConfigureAwait(false);
            if (root.ValueKind != JsonValueKind.Object || !profiles.EnumerateArray().Any(item => SeerrResponses.Int(item, "id") == profileId)) ArrOperations.Invalid();
            var rootPath = SeerrResponses.Property(root, "path").GetString();
            if (string.IsNullOrEmpty(rootPath)) throw new IntegrationException("invalid_response");
            var lookup = await _client.SendAsync(config, service, HttpMethod.Get,
                operation == "series" ? $"api/v3/series/lookup?term=tvdb:{id}" : $"api/v3/movie/lookup/tmdb?tmdbId={id}",
                null, null, cancellationToken).ConfigureAwait(false);
            if (lookup.ValueKind == JsonValueKind.Array)
                lookup = lookup.EnumerateArray().FirstOrDefault(item => SeerrResponses.Int(item, idKey) == id);
            if (SeerrResponses.Int(lookup, idKey) != id) throw new IntegrationException("not_found", 404);
            // Build from a fresh lookup: caller-supplied paths, IDs and nested options
            // can never override the administrator's approved destination.
            var payload = JsonNode.Parse(lookup.GetRawText())!.AsObject();
            payload.Remove("id");
            payload["rootFolderPath"] = rootPath;
            payload["qualityProfileId"] = profileId;
            payload["monitored"] = true;
            if (operation == "series") payload["seasonFolder"] = true;
            payload["addOptions"] = options;
            return JsonSerializer.SerializeToElement(payload);
        }
    }
}
