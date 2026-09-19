#!/usr/bin/env python3
"""Exercise the built plugin on an isolated Jellyfin 12 server (requires Docker)."""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dll', type=Path, default=Path(__file__).resolve().parents[1] /
                        'Jellyfin.Plugin.Driftfin/bin/Release/net10.0/Jellyfin.Plugin.Driftfin.dll')
    args = parser.parse_args()
    if not args.dll.is_file():
        parser.error('Build the Release plugin first')
    name = 'driftfin-plugin-test-' + secrets.token_hex(4)
    with tempfile.TemporaryDirectory(prefix='driftfin-plugin-test-') as tmp:
        config = Path(tmp)
        plugin = config / 'plugins/Driftfin'
        plugin.mkdir(parents=True)
        shutil.copy2(args.dll, plugin)
        saved = config / 'plugins/configurations'
        saved.mkdir()
        (saved / 'Jellyfin.Plugin.Driftfin.xml').write_text(
            '<PluginConfiguration><LocalUrl>http://legacy-server:8096</LocalUrl>'
            '<SeerrEnabled>true</SeerrEnabled><SeerrUrl>https://seerr.test</SeerrUrl>'
            '<SeerrApiKey>fixture-key</SeerrApiKey></PluginConfiguration>')
        try:
            subprocess.run(['docker', 'run', '-d', '--rm', '--name', name,
                            '--user', f'{os.getuid()}:{os.getgid()}',
                            '-p', '127.0.0.1::8096', '-v', f'{config}:/config',
                            '--tmpfs', '/cache:mode=1777', 'jellyfin/jellyfin:12.0'],
                           check=True, stdout=subprocess.DEVNULL)
            port = subprocess.check_output(['docker', 'port', name, '8096'], text=True).strip().split(':')[-1]
            base = f'http://127.0.0.1:{port}'

            def request(path, body=None, *, token='', device='admin', status=200, method=None):
                auth = f'MediaBrowser Client="Driftfin smoke", Device="Test", DeviceId="{device}", Version="1"'
                if token:
                    auth += f', Token="{token}"'
                headers = {'Authorization': auth, 'Content-Type': 'application/json'}
                data = None if body is None else json.dumps(body).encode()
                req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
                try:
                    response = urllib.request.urlopen(req, timeout=5)
                except urllib.error.HTTPError as error:
                    response = error
                with response:
                    assert response.status == status, f'{path}: expected {status}, got {response.status}'
                    content = response.read()
                    return json.loads(content) if content and response.headers.get_content_type() == 'application/json' else content

            deadline = time.monotonic() + 120
            while True:
                try:
                    request('/Startup/Configuration')
                    info = request('/System/Info/Public')
                    break
                except (OSError, AssertionError):
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Jellyfin did not start within 120 seconds') from None
                    time.sleep(1)
            assert info['Version'] == '12.0.0', info['Version']
            password = secrets.token_urlsafe(24)
            request('/Startup/Configuration', {'UICulture': 'en-US', 'MetadataCountryCode': 'US',
                                              'PreferredMetadataLanguage': 'en'}, status=204)
            request('/Startup/User')
            request('/Startup/User', {'Name': 'admin', 'Password': password}, status=204)
            request('/Startup/RemoteAccess', {'EnableRemoteAccess': False, 'EnableAutomaticPortMapping': False}, status=204)
            request('/Startup/Complete', {}, status=204)
            admin = request('/Users/AuthenticateByName', {'Username': 'admin', 'Pw': password})['AccessToken']
            plugins = request('/Plugins', token=admin)
            assert any(p['Name'] == 'Driftfin' and p['Status'] == 'Active' for p in plugins), 'Plugin not active'
            request('/Driftfin/Config', status=401)
            original = request('/Driftfin/Config', token=admin)
            assert original['localUrl'] == 'http://legacy-server:8096', 'Saved configuration was not migrated'
            assert original['seerr']['apiKey'] == 'fixture-key'
            original['localUrl'] = 'http://updated-server:8096'
            request('/Driftfin/Config', original, token=admin, status=204)
            assert request('/Driftfin/Config', token=admin)['localUrl'] == original['localUrl']
            request('/Users/New', {'Name': 'member', 'Password': password}, token=admin)
            member = request('/Users/AuthenticateByName', {'Username': 'member', 'Pw': password},
                             device='member')['AccessToken']
            request('/Driftfin/Config', token=member, device='member')
            request('/Driftfin/Config', original, token=member, device='member', status=403)
            request('/Driftfin/v1/capabilities', status=401)
            request('/Driftfin/v1/integrations/seerr/check', {}, token=member, device='member', status=403)
            original['seerr']['enabled'] = False
            request('/Driftfin/Config', original, token=admin, status=204)
            capabilities = request('/Driftfin/v1/capabilities', token=member, device='member')
            assert capabilities['protocolVersion'] == 1
            assert not capabilities['features']['arrManagement']['allowed']
            assert capabilities['integrations']['seerr']['reason'] == 'not_configured'
            assert 'fixture-key' not in json.dumps(capabilities)
            assert 'seerr.test' not in json.dumps(capabilities)
            diagnostics = request('/Driftfin/v1/integrations/seerr/check', {}, token=admin)
            assert diagnostics['reason'] == 'not_configured' and not diagnostics['healthy']
            assert diagnostics['correlationId'] and diagnostics['checkedAt']
            request('/Driftfin/v1/integrations/arbitrary/check', {}, token=admin, status=404)
            group = request('/SyncPlay/New', {'GroupName': 'Plugin test'}, token=admin)
            relay = f'/Driftfin/SyncPlay/{group["GroupId"]}/Messages'
            request(relay, {'kind': 'chat', 'text': 'outside'}, token=member, device='member', status=403)
            request('/SyncPlay/Join', {'GroupId': group['GroupId']}, token=member, device='member', status=204)
            groups = request('/SyncPlay/List', token=member, device='member')
            assert any('member' in g['Participants'] for g in groups), 'Member did not join'
            policy = request('/Users/Me', token=member, device='member')['Policy']
            assert not policy['EnableRemoteControlOfOtherUsers'], 'Test user must not control other users'
            request(relay, {'kind': 'chat', 'text': 'inside'}, token=member, device='member', status=204)
            request('/web/configurationpage?name=Driftfin', token=admin)
            print('PASS: Jellyfin 12 loads plugin; saved config, admin/user permissions, and SyncPlay membership work.')
        finally:
            subprocess.run(['docker', 'rm', '-f', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
