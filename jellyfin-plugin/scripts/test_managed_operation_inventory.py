"""Keep managed routes in step with the app's existing Seerr API inventory."""
from pathlib import Path
import re
import unittest


class ManagedOperationInventoryTests(unittest.TestCase):
    def test_arr_client_paths_have_explicit_routes(self):
        root = Path(__file__).resolve().parents[2]
        controller = (root / 'jellyfin-plugin/Jellyfin.Plugin.Driftfin/Api/DriftfinArrController.cs').read_text()
        routes = set(re.findall(r'\[Http(?:Get|Post|Put)\("([^"]+)"\)\]', controller))
        for service in ('sonarr', 'radarr'):
            client = (root / f'lib/providers/{service}_provider.dart').read_text()
            for path in re.findall(r"_uri\('([^']+)'", client):
                with self.subTest(service=service, path=path):
                    self.assertIn(path, routes)

    def test_every_client_operation_has_an_explicit_route_or_direct_login_exception(self):
        root = Path(__file__).resolve().parents[2]
        client = (root / 'lib/seerr/seerr_chopper_service.dart').read_text()
        controller = (root / 'jellyfin-plugin/Jellyfin.Plugin.Driftfin/Api/DriftfinSeerrController.cs').read_text()

        def normalize(path):
            return re.sub(r'\{[^}]+\}', '{id}', path.strip('/'))

        routes = {(method.upper(), normalize(path))
                  for method, path in re.findall(r'\[Http(Get|Post|Delete|Put)\("([^"]+)"\)\]', controller)}
        # Managed mode uses the Jellyfin session. These password/cookie operations
        # remain available only through the app's explicitly configured direct mode.
        direct_only = {('POST', '/auth/local'), ('POST', '/auth/jellyfin'), ('POST', '/auth/logout')}
        for method, path in re.findall(r"@(GET|POST|DELETE|PUT)\(path: '([^']+)'\)", client):
            if (method, path) in direct_only:
                continue
            paths = [path.replace('{status}', status) for status in ('available', 'partial', 'processing', 'pending', 'unknown')] if '{status}' in path else [path]
            for candidate in paths:
                with self.subTest(method=method, path=candidate):
                    self.assertIn((method, normalize(candidate)), routes)


if __name__ == '__main__':
    unittest.main()
