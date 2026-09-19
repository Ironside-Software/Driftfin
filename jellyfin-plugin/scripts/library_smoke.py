"""Real Jellyfin scans and user-scoped matching against controlled catalog metadata."""
from copy import deepcopy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import secrets
import shutil
import subprocess
from threading import Thread
import time
from urllib.parse import urlencode


def check_library(request, admin, member, configuration, server_id, container, config_path):
    root = config_path / 'fixture-media'
    root.mkdir()
    subprocess.run(['docker', 'exec', container, '/usr/lib/jellyfin-ffmpeg/ffmpeg', '-v', 'error',
                    '-f', 'lavfi', '-i', 'color=c=black:s=160x90:d=1', '-an', '-c:v', 'mpeg4',
                    '-threads', '1', '/config/fixture-media/sample.mkv'], check=True)
    for folder, title, tmdb in [('Owned', 'Different title', 550), ('Decoy', 'Unowned movie', 9999)]:
        directory = root / 'movies' / folder
        directory.mkdir(parents=True)
        shutil.copy2(root / 'sample.mkv', directory / f'{folder}.mkv')
        (directory / f'{folder}.nfo').write_text(f'<movie><title>{title}</title><tmdbid>{tmdb}</tmdbid>'
                                              f'<uniqueid type="tmdb" default="true">{tmdb}</uniqueid></movie>')
    for folder, tmdb, episode in [('Partial', 1396, 'S01E01'), ('Complete', 859, 'S01E01-E02')]:
        directory = root / 'shows' / folder
        directory.mkdir(parents=True)
        (directory / 'tvshow.nfo').write_text(f'<tvshow><title>{folder}</title><tmdbid>{tmdb}</tmdbid>'
                                            f'<uniqueid type="tmdb" default="true">{tmdb}</uniqueid></tvshow>')
        shutil.copy2(root / 'sample.mkv', directory / f'{folder} {episode}.mkv')
    for name, collection, folder in [('FixtureMovies', 'movies', 'movies'), ('FixtureShows', 'tvshows', 'shows')]:
        options = {'EnableRealtimeMonitor': False, 'MetadataReaders': ['Nfo'], 'MetadataSavers': [],
                   'TypeOptions': [{'Type': kind, 'MetadataFetchers': [], 'ImageFetchers': []}
                                   for kind in ['Movie', 'Series', 'Season', 'Episode']]}
        query = urlencode({'name': name, 'collectionType': collection, 'paths': f'/config/fixture-media/{folder}',
                           'refreshLibrary': 'false'})
        request('/Library/VirtualFolders?' + query, {'LibraryOptions': options}, token=admin, status=204)
    request('/Library/Refresh', {}, token=admin, status=204)
    deadline = time.monotonic() + 90
    while True:
        items = request('/Items?Recursive=true&IncludeItemTypes=Movie,Series,Episode&Fields=ProviderIds', token=admin)['Items']
        by_tmdb = {item.get('ProviderIds', {}).get('Tmdb'): item for item in items if item.get('ProviderIds', {}).get('Tmdb')}
        if all(str(identity) in by_tmdb for identity in [550, 9999, 1396, 859]) and sum(item['Type'] == 'Episode' for item in items) >= 2:
            break
        if time.monotonic() >= deadline:
            raise AssertionError('Fixture library did not finish scanning the expected metadata')
        time.sleep(1)

    member_id = request('/Users/Me', token=member, device='member')['Id']
    admin_id = request('/Users/Me', token=admin)['Id']
    key = secrets.token_urlsafe(24)
    details = []

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            assert self.headers.get('X-Api-Key') == key
            path = self.path.split('?')[0]
            if path.endswith('/status'):
                body = {'version': '3.4.1'}
            elif path.endswith('/settings/jellyfin'):
                body = {'serverId': server_id}
            elif path.endswith('/user'):
                body = {'results': [{'id': 42, 'jellyfinUserId': member_id}, {'id': 43, 'jellyfinUserId': admin_id}]}
            elif path.endswith('/auth/me'):
                body = {'id': int(self.headers.get('X-API-User', '1')), 'permissions': 32}
            elif path.endswith('/search'):
                assert self.headers.get('X-API-User') in ('42', '43')
                body = {'page': 1, 'totalPages': 1, 'results': [
                    {'id': 550, 'mediaType': 'movie', 'title': 'Catalog title'},
                    {'id': 680, 'mediaType': 'movie', 'title': 'Unowned movie', 'mediaInfo': {'status': 5, 'requests': []}},
                    {'id': 1396, 'mediaType': 'tv', 'name': 'Partial'},
                    {'id': 859, 'mediaType': 'tv', 'name': 'Complete'},
                ]}
            elif '/tv/' in path:
                identity = int(path.rsplit('/', 1)[1])
                details.append(identity)
                body = {'id': identity, 'numberOfEpisodes': 2, 'seasons': [{'seasonNumber': 1, 'episodeCount': 2}]}
            else:
                raise AssertionError('Unexpected catalog operation')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(body).encode())

    upstream = ThreadingHTTPServer(('0.0.0.0', 0), Handler)
    thread = Thread(target=upstream.serve_forever, daemon=True)
    thread.start()
    gateway = subprocess.check_output(['docker', 'network', 'inspect', 'bridge', '--format', '{{(index .IPAM.Config 0).Gateway}}'], text=True).strip()
    configured = deepcopy(configuration)
    configured['seerr'] = {'enabled': True, 'url': f'http://{gateway}:{upstream.server_port}', 'apiKey': key}
    policy = request('/Users/Me', token=member, device='member')['Policy']
    try:
        request('/Driftfin/Config', configured, token=admin, status=204)

        def search():
            result = request('/Driftfin/v1/discovery/search?query=fixture', token=member, device='member')
            serialized = json.dumps(result)
            assert key not in serialized and '/config/' not in serialized and 'ProviderIds' not in serialized
            return {item['tmdbId']: item for item in result['results']}

        results = search()
        assert results[550]['availability'] == 'available' and results[550]['canPlay']
        assert results[550]['libraryItemId'] == by_tmdb['550']['Id'].replace('-', '')
        assert results[680]['availability'] == 'requestable' and results[680]['libraryItemId'] is None
        assert results[1396]['availability'] == 'partial'
        assert results[859]['availability'] == 'available', 'Combined episode file was not counted correctly'
        assert set(details) == {1396, 859}, 'Untracked owned shows need catalog episode totals'
        no_play = dict(policy, EnableMediaPlayback=False)
        request(f'/Users/{member_id}/Policy', no_play, token=admin, status=204)
        assert not search()[550]['canPlay']
        restricted = dict(policy, EnableAllFolders=False, EnabledFolders=[])
        request(f'/Users/{member_id}/Policy', restricted, token=admin, status=204)
        request('/Driftfin/v1/discovery/search?query=fixture', token=member, device='member', status=403)
        print('PASS: native library matching uses provider IDs, counts combined episodes, and respects user policy.')
    finally:
        request(f'/Users/{member_id}/Policy', policy, token=admin, status=204)
        request('/Driftfin/Config', configuration, token=admin, status=204)
        upstream.shutdown()
        upstream.server_close()
        thread.join()
