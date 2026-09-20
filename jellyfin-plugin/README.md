# Driftfin — Jellyfin server plugin

Optional Jellyfin **server** plugin for managed Seerr, Sonarr and Radarr
integrations, diagnostics and unified discovery in Driftfin. Integration API
keys stay on the server. Core Jellyfin browsing and playback work without it;
explicitly configured manual integrations remain available.
After removing a managed plugin, choose **Settings → Integrations → Use manual
integrations** to restore confirmed manual connections. A timeout or login failure
never enables this action. Reinstalling the managed plugin restores managed mode
on the next successful capability refresh. The Jellyfin LAN address remains part
of the bootstrap; integration server addresses and credentials stay private.


## How it works

- Driftfin negotiates the non-secret `GET /Driftfin/v1/capabilities` contract.
  Managed operations use the user's Jellyfin session.
- An administrator configures integrations through **Dashboard → Plugins →
  Driftfin**. Sonarr/Radarr management and connection diagnostics require a
  Jellyfin administrator.
- Seerr operations require an exact mapping to the caller's Jellyfin user on
  the paired server. Requests retain that user's permissions, ownership and
  quotas; no owner-account fallback is allowed. The verified managed Seerr
  version is 3.4.1; unsupported versions fail closed.
- Unified discovery matches catalog results to the caller's accessible Jellyfin
  library by provider IDs. Restricted library policies disable discovery when
  catalog visibility cannot be guaranteed.
- The plugin also exposes `POST /Driftfin/SyncPlay/{groupId}/Messages`, which
  any authenticated group member may call to relay a Watch Together chat
  message, emoji reaction, or typing/buffering presence ping to the rest of
  the group. Jellyfin's own session-message API only reaches sessions the
  caller can remote-control (normally administrators only); this endpoint
  runs with the plugin's own trusted access to the session manager, so it
  reaches every group member regardless of permissions — the fix for
  Driftfin issue #4. Without the plugin, chat still works between clients
  where one side has remote-control rights; reactions/presence are local-only.

## Upgrade from plugin 1 or 2

Plugin **3.0.0.0** retires the secret-sharing `GET /Driftfin/Config` contract.
It returns HTTP 426 with `upgrade_required` to authenticated clients. Saved
server configuration and the plugin GUID are preserved; this does not erase
keys already copied to older clients.

1. Deploy a compatible Driftfin app before upgrading the plugin. Older apps
   retain core Jellyfin functionality but must upgrade to use managed integrations.
2. Verify the deployed Seerr and arr versions, then upgrade the plugin and
   restart Jellyfin. Keep older-server artifacts in the catalog.
3. Refresh integrations in Driftfin and use the administrator connection checks.
   Regular users need their own mapped Seerr account.
4. Reconnect integrations whose old local credentials have unknown provenance.
   Personal Trakt OAuth remains local; the new plugin no longer distributes
   Trakt application secrets. Configure a personal Trakt application explicitly.
   When using an older plugin, server-provided Trakt sessions last for the app
   session; they never overwrite saved personal Trakt credentials or tokens.
5. After migration, administrators should rotate previously distributed
   integration keys in each service and update the plugin dashboard. Rotation
   is deliberately manual.

There is no legacy key-sharing compatibility switch. The admin-only configuration
write route remains available, and Jellyfin's standard plugin configuration API
continues to serve the dashboard.

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

Plugins 2 and 3 target the exact Jellyfin 12.0.0 API. Jellyfin 10.x must keep the
older plugin; changing its manifest alone cannot make its DLL compatible with 12.
The plugin GUID and configuration filename stay the same, so upgrading retains
saved settings. After updating, restart Jellyfin and refresh integrations in Driftfin.

CI validates the catalog ABI/framework against the project, tests the plugin,
and starts Jellyfin 12 in Docker to verify loading, existing configuration,
admin/user permissions and SyncPlay group membership. Run the same checks locally:

```bash
dotnet test jellyfin-plugin/Jellyfin.Plugin.Driftfin.Tests/Jellyfin.Plugin.Driftfin.Tests.csproj -c Release
python3 -m unittest discover -s jellyfin-plugin/scripts -p 'test_*.py' -v
python3 jellyfin-plugin/scripts/smoke_test.py --with-seerr
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
