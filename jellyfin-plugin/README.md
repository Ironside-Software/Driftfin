# Driftfin — Jellyfin server plugin

Optional Jellyfin **server** plugin that stores Driftfin's client integration
settings — Jellyseerr/Overseerr, Sonarr, Radarr and Trakt — **once, on the
server**, so every Driftfin client pulls one shared configuration instead of
each user re-entering URLs and API keys on every device.

The Driftfin app works **fully without this plugin** — it just falls back to its
normal per-device settings. Install the plugin only if you want centrally
managed integrations.

## How it works

- The plugin exposes `GET /Driftfin/Config`, which returns the configured
  integrations as JSON to any authenticated Jellyfin user. Driftfin calls this
  on login; a `404` simply means the plugin isn't installed.
- An admin edits the values from **Dashboard → Plugins → Driftfin**
  (or via the admin-only `POST /Driftfin/Config`).
- Any integration that is enabled **and** fully filled in becomes
  *server-managed*: Driftfin uses those values and shows the matching in-app
  fields as read-only ("Managed by server").
- The plugin also exposes `POST /Driftfin/SyncPlay/{groupId}/Messages`, which
  any authenticated group member may call to relay a Watch Together chat
  message, emoji reaction, or typing/buffering presence ping to the rest of
  the group. Jellyfin's own session-message API only reaches sessions the
  caller can remote-control (normally administrators only); this endpoint
  runs with the plugin's own trusted access to the session manager, so it
  reaches every group member regardless of permissions — the fix for
  Driftfin issue #4. Without the plugin, chat still works between clients
  where one side has remote-control rights; reactions/presence are local-only.

> **Security note:** `GET /Driftfin/Config` returns the stored values —
> including API keys — to every logged-in user (this matches how Driftfin
> already lets each user hold these keys client-side). Don't enable it on a
> server where untrusted users shouldn't see your *.arr keys.

Per-user secrets are never centralized: Trakt OAuth tokens and Jellyseerr
session cookies are still established locally on each device.

## Build from source

Requires the .NET 10 SDK.

```bash
dotnet build jellyfin-plugin/Jellyfin.Plugin.Driftfin/Jellyfin.Plugin.Driftfin.csproj -c Release
```

The plugin DLL lands in
`jellyfin-plugin/Jellyfin.Plugin.Driftfin/bin/Release/net10.0/Jellyfin.Plugin.Driftfin.dll`.

### Supported servers

| Jellyfin server | Driftfin plugin | Framework |
| --- | --- | --- |
| 12.x | 2.0.0.0 and later | .NET 10 |
| 10.10 / 10.11 | 1.0.2.0 (retained in the catalog) | .NET 8 |

Plugin 2 targets the exact Jellyfin 12.0.0 API. Jellyfin 10.x must keep the
older plugin; changing its manifest alone cannot make its DLL compatible with 12.
The plugin GUID and configuration filename stay the same, so upgrading retains
saved settings. After updating, restart Jellyfin and refresh integrations in Driftfin.

CI validates the catalog ABI/framework against the project, tests the plugin,
and starts Jellyfin 12 in Docker to verify loading, existing configuration,
admin/user permissions and SyncPlay group membership. Run the same checks locally:

```bash
dotnet test jellyfin-plugin/Jellyfin.Plugin.Driftfin.Tests/Jellyfin.Plugin.Driftfin.Tests.csproj -c Release
python3 -m unittest discover -s jellyfin-plugin/scripts -p 'test_*.py' -v
python3 jellyfin-plugin/scripts/smoke_test.py
```

The Python metadata tests require PyYAML. The smoke test requires Docker and
uses a temporary server bound to loopback; it never connects to your existing server.

## Install into Jellyfin

**Via a plugin repository (recommended):** add

```
https://ironside-software.github.io/Driftfin/jellyfin-plugin/manifest.json
```

under **Dashboard → Plugins → Repositories**, then find "Driftfin" under
**Catalog** and install it. Future versions show up there too — updating is a
normal Jellyfin plugin update, no manual file copying.

**Manual:** grab `driftfin-plugin-*.zip` from the
[plugin releases](https://github.com/Ironside-Software/Driftfin/releases?q=plugin-v),
unzip it into a `Driftfin` folder under your Jellyfin `plugins/` directory, and
restart the server.

Then open **Dashboard → Plugins → Driftfin** and fill in the integrations.

## Release process (maintainers)

The manifest above is generated and deployed automatically by the `Plugin
(Jellyfin)` GitHub Actions workflow (`.github/workflows/plugin.yaml`) — it
publishes the exact ZIP that passed unit and Jellyfin 12 smoke tests, computes its MD5
checksum, and merges a new entry into the manifest hosted on GitHub Pages
(`gh-pages`, same branch as the landing site — the two deploys are configured
with `keep_files: true` so neither wipes the other's content).

To cut a release:

1. Bump `version` in [`build.yaml`](build.yaml) **and** the
   `<Version>` field in
   [`Jellyfin.Plugin.Driftfin.csproj`](Jellyfin.Plugin.Driftfin/Jellyfin.Plugin.Driftfin.csproj)
   — they must match, and the workflow verifies this. Assembly and file versions
   are derived from `<Version>` by the .NET SDK.
2. Merge that change.
3. `git tag plugin-vX.Y.Z.W && git push origin plugin-vX.Y.Z.W`

You can still build a local zip/manifest by hand with
[`jprm`](https://github.com/oddstr13/jellyfin-plugin-repository-manager)
(`pip install jprm && jprm plugin build jellyfin-plugin`) if you want to test
a repository without waiting on CI.
