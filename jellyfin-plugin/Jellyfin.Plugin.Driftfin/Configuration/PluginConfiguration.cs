using MediaBrowser.Model.Plugins;

namespace Jellyfin.Plugin.Driftfin.Configuration
{
    /// <summary>
    /// Server-wide Driftfin client integration settings. Configured by an admin
    /// in the Jellyfin dashboard and served to clients via the plugin's
    /// <c>GET /Driftfin/Config</c> endpoint.
    /// </summary>
    public class PluginConfiguration : BasePluginConfiguration
    {
        // Configuration fields are strings/booleans. One request must not mix
        // identity lookup on the old integration with a mutation on a new one.
        internal PluginConfiguration Snapshot() => (PluginConfiguration)MemberwiseClone();

        /// <summary>Gets or sets the server-wide local (LAN) URL for reaching this Jellyfin server.</summary>
        public string LocalUrl { get; set; } = string.Empty;

        /// <summary>Gets or sets a value indicating whether Jellyseerr is provided server-side.</summary>
        public bool SeerrEnabled { get; set; }

        /// <summary>Gets or sets the Jellyseerr/Overseerr base URL.</summary>
        public string SeerrUrl { get; set; } = string.Empty;

        /// <summary>Gets or sets the Jellyseerr/Overseerr API key.</summary>
        public string SeerrApiKey { get; set; } = string.Empty;

        /// <summary>Gets or sets a value indicating whether Sonarr is provided server-side.</summary>
        public bool SonarrEnabled { get; set; }

        /// <summary>Gets or sets the Sonarr base URL.</summary>
        public string SonarrUrl { get; set; } = string.Empty;

        /// <summary>Gets or sets the Sonarr API key.</summary>
        public string SonarrApiKey { get; set; } = string.Empty;

        /// <summary>Gets or sets a value indicating whether Radarr is provided server-side.</summary>
        public bool RadarrEnabled { get; set; }

        /// <summary>Gets or sets the Radarr base URL.</summary>
        public string RadarrUrl { get; set; } = string.Empty;

        /// <summary>Gets or sets the Radarr API key.</summary>
        public string RadarrApiKey { get; set; } = string.Empty;

        /// <summary>Gets or sets a value indicating whether Trakt app credentials are provided server-side.</summary>
        public bool TraktEnabled { get; set; }

        /// <summary>Gets or sets the Trakt application client id.</summary>
        public string TraktClientId { get; set; } = string.Empty;

        /// <summary>Gets or sets the Trakt application client secret.</summary>
        public string TraktClientSecret { get; set; } = string.Empty;
    }
}
