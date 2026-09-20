"""Controlled arr upstreams behind a real Jellyfin authorization boundary."""
from copy import deepcopy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import secrets
import subprocess
from threading import Thread


def check_arr(request, admin, member, original):
    key = secrets.token_urlsafe(24)
    calls = []
    fail = [False]

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            self.respond()

        def do_POST(self):
            self.respond()

        def do_PUT(self):
            self.respond()

        def respond(self):
            assert self.headers.get('X-Api-Key') == key
            assert not self.headers.get('Authorization')
            assert not self.headers.get('Cookie')
            assert not self.headers.get('X-API-User')
            body = json.loads(self.rfile.read(int(self.headers['Content-Length']))) if self.headers.get('Content-Length') else None
            path = self.path.split('?')[0]
            calls.append((self.command, path, body))
            if fail[0]:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(b'private upstream failure')
                return
            resource = path.split('/api/v3/')[-1]
            data = {
                'series': [{'id': 9, 'tvdbId': 7, 'path': 'private', 'apiKey': key}],
                'movie': [{'id': 8, 'tmdbId': 550, 'path': 'private', 'apiKey': key}],
                'series/lookup': [{'tvdbId': 7, 'title': 'Actual series'}],
                'movie/lookup/tmdb': {'tmdbId': 550, 'title': 'Actual movie'},
                'episode': [{'id': 12, 'seasonNumber': 1, 'episodeNumber': 1, 'episodeFile': {'path': 'private'}}],
                'rootfolder': [{'id': 4, 'path': '/server/media', 'accessible': True}],
                'qualityprofile': [{'id': 2, 'name': 'HD', 'secret': key}],
                'calendar': [{'id': 12, 'title': 'Episode', 'series': {'title': 'Series', 'tvdbId': 7, 'path': 'private'}}],
                'system/status': {'version': '4.0.0'},
            }.get(resource, {})
            if self.command != 'GET':
                if resource in ('series', 'movie'):
                    assert body['rootFolderPath'] == '/server/media'
                    assert body['qualityProfileId'] == 2
                    assert body['title'].startswith('Actual')
                data = {'id': 9, 'path': 'private', 'apiKey': key}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())

    server = ThreadingHTTPServer(('0.0.0.0', 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    gateway = subprocess.check_output(['docker', 'network', 'inspect', 'bridge', '--format', '{{(index .IPAM.Config 0).Gateway}}'], text=True).strip()
    config = deepcopy(original)
    try:
        for service in ('sonarr', 'radarr'):
            config[service] = {'enabled': True, 'url': f'http://{gateway}:{server.server_port}/{service}', 'apiKey': key}
        request('/Driftfin/Config', config, token=admin, status=204)
        for service in ('sonarr', 'radarr'):
            prefix = f'/Driftfin/v1/{service}/'
            routes = ['rootfolder', 'qualityprofile', 'calendar?start=2026-01-01&end=2026-02-01']
            routes += ['series', 'series/lookup?term=tvdb:7', 'episode?seriesId=9'] if service == 'sonarr' else ['movie?tmdbId=550', 'movie/lookup/tmdb?tmdbId=550']
            for route in routes:
                before = len(calls)
                request(prefix + route, token=member, device='member', status=403)
                assert len(calls) == before
                data = request(prefix + route, token=admin)
                serialized = json.dumps(data)
                assert key not in serialized and 'private' not in serialized and '/server/media' not in serialized
            request(prefix + 'command', {'name': 'DeleteEverything'}, token=admin, status=400)
            request(prefix + 'command', {'name': 'EpisodeSearch' if service == 'sonarr' else 'MoviesSearch',
                                        'episodeIds' if service == 'sonarr' else 'movieIds': [9]}, token=admin)
            body = {'tvdbId' if service == 'sonarr' else 'tmdbId': 7 if service == 'sonarr' else 550,
                    'rootFolderPath': 'folder:4', 'qualityProfileId': 2, 'monitored': True,
                    'addOptions': {'monitor': 'none', 'searchForMissingEpisodes': False, 'searchForCutoffUnmetEpisodes': False}
                    if service == 'sonarr' else {'searchForMovie': True}}
            if service == 'sonarr':
                body['seasonFolder'] = True
            route = prefix + ('series' if service == 'sonarr' else 'movie')
            request(route, body, token=member, device='member', status=403)
            request(route, body, token=admin)
            body['rootFolderPath'] = '/arbitrary/path'
            request(route, body, token=admin, status=400)
            fail[0] = True
            result = request(prefix + 'rootfolder', token=admin, status=502)
            assert result['reason'] == 'upstream_error' and 'private' not in json.dumps(result)
            fail[0] = False
        request('/Driftfin/v1/sonarr/episode/monitor', {'episodeIds': [12], 'monitored': True}, method='PUT', token=admin)
        print('PASS: managed arr admin actions, member denial, approved destinations, projection, and redacted failures.')
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
        request('/Driftfin/Config', original, token=admin, status=204)
