"""Real Seerr identity/permission checks for the disposable Jellyfin smoke server."""
import json
import os
from pathlib import Path
import secrets
import sqlite3
import subprocess
import tempfile
import time
import urllib.request


def check_seerr(request, admin, member, configuration, server_id):
    name = 'driftfin-seerr-test-' + secrets.token_hex(4)
    with tempfile.TemporaryDirectory(prefix='driftfin-seerr-test-') as directory:
        root = Path(directory)
        root.chmod(0o777)  # Disposable fixture; the image runs as its own node UID.
        key = secrets.token_urlsafe(32)
        settings = {
            'main': {'apiKey': key, 'mediaServerType': 2, 'versionCheck': False},
            'public': {'initialized': True},
            'jellyfin': {'serverId': server_id, 'apiKey': secrets.token_urlsafe(32)},
        }
        (root / 'settings.json').write_text(json.dumps(settings))
        (root / 'settings.json').chmod(0o666)
        try:
            subprocess.run(['docker', 'run', '-d', '--name', name,
                            '-p', '127.0.0.1::5055', '-v', f'{root}:/app/config',
                            'ghcr.io/seerr-team/seerr:v3.4.1'], check=True, stdout=subprocess.DEVNULL)
            port = subprocess.check_output(['docker', 'port', name, '5055'], text=True).strip().split(':')[-1]
            endpoint = f'http://127.0.0.1:{port}'

            def wait():
                deadline = time.monotonic() + 90
                while True:
                    try:
                        with urllib.request.urlopen(endpoint + '/api/v1/status', timeout=2) as response:
                            assert json.load(response)['version'].lstrip('v') == '3.4.1'
                        return
                    except (OSError, AssertionError):
                        running = subprocess.check_output(['docker', 'inspect', '--format', '{{.State.Running}}', name], text=True).strip()
                        if running != 'true':
                            raise RuntimeError('Seerr fixture exited during startup') from None
                        if time.monotonic() >= deadline:
                            raise RuntimeError('Seerr fixture did not start') from None
                        time.sleep(1)

            wait()
            subprocess.run(['docker', 'stop', name], check=True, stdout=subprocess.DEVNULL)
            admin_id = request('/Users/Me', token=admin)['Id']
            member_id = request('/Users/Me', token=member, device='member')['Id']
            password = secrets.token_urlsafe(24)
            manager_id = request('/Users/New', {'Name': 'request-manager', 'Password': password}, token=admin)['Id']
            manager = request('/Users/AuthenticateByName', {'Username': 'request-manager', 'Pw': password},
                              device='manager')['AccessToken']
            request('/Users/New', {'Name': 'unlinked', 'Password': password}, token=admin)
            unlinked = request('/Users/AuthenticateByName', {'Username': 'unlinked', 'Pw': password},
                               device='unlinked')['AccessToken']
            # Only fixture users are seeded. Every tested action goes through the real
            # Seerr HTTP middleware, quota calculation, request entity and approval routes.
            with sqlite3.connect(root / 'db/db.sqlite3') as database:
                for identity, jellyfin_id, permissions, quota in (
                    (1, secrets.token_hex(16), 2, 0),
                    (42, member_id, 32, 1),
                    (43, admin_id, 32, 2),
                    (44, manager_id, 32 | 16, 0),
                ):
                    database.execute('INSERT INTO "user" (id,email,username,avatar,permissions,userType,jellyfinUserId,'
                                     'movieQuotaLimit,movieQuotaDays) VALUES (?,?,?,?,?,?,?,?,?)',
                                     (identity, f'user{identity}@example.test', f'user{identity}', '', permissions, 3,
                                      jellyfin_id, quota, 7))
            subprocess.run(['docker', 'start', name], check=True, stdout=subprocess.DEVNULL)
            port = subprocess.check_output(['docker', 'port', name, '5055'], text=True).strip().split(':')[-1]
            endpoint = f'http://127.0.0.1:{port}'
            wait()
            ip = subprocess.check_output(['docker', 'inspect', '--format',
                                          '{{(index .NetworkSettings.Networks "bridge").IPAddress}}', name], text=True).strip()
            configured = dict(configuration)
            configured['seerr'] = {'enabled': True, 'url': f'http://{ip}:5055', 'apiKey': key}
            request('/Driftfin/Config', configured, token=admin, status=204)
            prefix = '/Driftfin/v1/seerr'
            me = request(prefix + '/auth/me', token=member, device='member', extra_headers={'X-API-User': '1'})
            assert me['id'] == 42 and me['permissions'] == 32, 'Member inherited owner privileges'
            assert 'plexToken' not in me and key not in json.dumps(me)
            assert request(prefix + '/auth/me', token=admin)['id'] == 43, 'Jellyfin admin became Seerr owner'
            capability = request('/Driftfin/v1/capabilities', token=unlinked, device='unlinked')
            assert capability['integrations']['seerr']['reason'] == 'user_not_linked'
            request(prefix + '/auth/me', token=unlinked, device='unlinked', status=403)
            request(prefix + '/user/43/quota', token=member, device='member', status=403)
            request(prefix + '/request', {'mediaType': 'movie', 'mediaId': 550, 'userId': 1},
                    token=member, device='member', status=403)
            request(prefix + '/request', {'mediaType': 'movie', 'mediaId': 550, 'is4k': True},
                    token=member, device='member', status=403)
            first = request(prefix + '/request', {'mediaType': 'movie', 'mediaId': 550, 'is4k': False},
                            token=member, device='member')
            assert first['requestedBy']['id'] == 42 and first['status'] == 1, 'Attribution or approval bypass'
            quota = request(prefix + '/user/42/quota', token=member, device='member')
            assert quota['movie']['remaining'] == 0 and quota['movie']['restricted']
            request(prefix + '/request', {'mediaType': 'movie', 'mediaId': 680, 'is4k': False},
                    token=member, device='member', status=403)
            second = request(prefix + '/request', {'mediaType': 'movie', 'mediaId': 680, 'is4k': False}, token=admin)
            assert second['requestedBy']['id'] == 43 and second['status'] == 1
            own = request(prefix + '/request', token=member, device='member')['results']
            assert [entry['id'] for entry in own] == [first['id']], 'Other-user requests leaked'
            request(prefix + f'/request/{first["id"]}/approve', {}, token=member, device='member', status=403)
            approved = request(prefix + f'/request/{first["id"]}/approve', {}, token=manager, device='manager')
            assert approved['status'] == 2 and approved['modifiedBy']['id'] == 44
            assert approved['requestedBy']['id'] == 42
            request(prefix + '/settings/main', token=member, device='member', status=404)
            search = request('/Driftfin/v1/discovery/search?query=Fight%20Club', token=member, device='member')
            movie = next(item for item in search['results'] if item['tmdbId'] == 550 and item['mediaType'] == 'movie')
            assert movie['availability'] == 'requested' and not movie['canPlay'] and movie['libraryItemId'] is None
            assert key not in json.dumps(search) and 'serviceUrl' not in json.dumps(search)
            policy = request('/Users/Me', token=member, device='member')['Policy']
            policy['MaxParentalRating'] = 10
            request(f'/Users/{member_id}/Policy', policy, token=admin, status=204)
            restricted = request('/Driftfin/v1/capabilities', token=member, device='member')
            assert restricted['features']['discovery']['reason'] == 'content_restricted'
            request('/Driftfin/v1/discovery/search?query=Fight%20Club', token=member, device='member', status=403)
            print('PASS: real Seerr 3.4.1 preserves two-user attribution, quotas, approvals and missing mappings.')
        except Exception:
            logs = subprocess.run(['docker', 'logs', '--tail', '80', name], capture_output=True, text=True)
            descriptor = os.open('/tmp/driftfin-seerr-fixture.log', os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(descriptor, 'w') as output:
                output.write((logs.stdout + logs.stderr).replace(key, '[redacted]'))
            raise
        finally:
            subprocess.run(['docker', 'rm', '-f', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
