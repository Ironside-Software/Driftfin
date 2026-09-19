using System.Reflection;
using System.Text.Json;
using Jellyfin.Plugin.Driftfin.Api;
using Jellyfin.Plugin.Driftfin.Configuration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xunit;

namespace Jellyfin.Plugin.Driftfin.Tests
{
    public class DriftfinConfigDtoTests
    {
        [Fact]
        public void LegacyRead_ReturnsOnlyUpgradeNotice()
        {
            var result = Assert.IsType<ObjectResult>(new DriftfinConfigController().GetConfig());
            Assert.Equal(426, result.StatusCode);
            Assert.Equal("{\"reason\":\"upgrade_required\",\"protocolVersion\":1}",
                JsonSerializer.Serialize(result.Value));
            Assert.NotNull(typeof(DriftfinConfigController).GetMethod("GetConfig")!
                .GetCustomAttribute<AuthorizeAttribute>());
        }

        [Fact]
        public void ConfigurationWrites_RequireAdministrator()
        {
            var authorization = typeof(DriftfinConfigController).GetMethod("UpdateConfig")!
                .GetCustomAttribute<AuthorizeAttribute>();
            Assert.Equal("RequiresElevation", authorization!.Policy);
        }

        [Fact]
        public void ApplyTo_PreservesAllConfigurationFields()
        {
            var dto = new DriftfinConfigDto
            {
                LocalUrl = "http://lan:8096",
                Seerr = new SeerrConfigDto { Enabled = true, Url = "http://seerr", ApiKey = "seerr-key" },
                Sonarr = new ArrConfigDto { Enabled = true, Url = "http://sonarr", ApiKey = "sonarr-key" },
                Radarr = new ArrConfigDto { Enabled = false, Url = "http://radarr", ApiKey = "radarr-key" },
                Trakt = new TraktConfigDto { Enabled = true, ClientId = "client", ClientSecret = "secret" },
            };
            var config = new PluginConfiguration();
            dto.ApplyTo(config);
            Assert.Equal(dto.LocalUrl, config.LocalUrl);
            Assert.Equal(dto.Seerr.Enabled, config.SeerrEnabled);
            Assert.Equal(dto.Seerr.Url, config.SeerrUrl);
            Assert.Equal(dto.Seerr.ApiKey, config.SeerrApiKey);
            Assert.Equal(dto.Sonarr.Enabled, config.SonarrEnabled);
            Assert.Equal(dto.Sonarr.Url, config.SonarrUrl);
            Assert.Equal(dto.Sonarr.ApiKey, config.SonarrApiKey);
            Assert.Equal(dto.Radarr.Enabled, config.RadarrEnabled);
            Assert.Equal(dto.Radarr.Url, config.RadarrUrl);
            Assert.Equal(dto.Radarr.ApiKey, config.RadarrApiKey);
            Assert.Equal(dto.Trakt.Enabled, config.TraktEnabled);
            Assert.Equal(dto.Trakt.ClientId, config.TraktClientId);
            Assert.Equal(dto.Trakt.ClientSecret, config.TraktClientSecret);
        }
    }
}
