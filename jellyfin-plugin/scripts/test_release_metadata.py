import copy
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

import yaml
from validate_metadata import validate


class ReleaseMetadataTests(unittest.TestCase):
    def test_actual_release_metadata_matches_build_and_tag(self):
        root = Path(__file__).resolve().parents[1]
        meta = yaml.safe_load((root / 'build.yaml').read_text())
        project = ET.parse(root / 'Jellyfin.Plugin.Driftfin/Jellyfin.Plugin.Driftfin.csproj').getroot()
        self.assertEqual(validate(meta, project, 'plugin-v' + meta['version']), (meta['version'], meta['framework']))
        for field, value in [('version', '0.0.0.0'), ('framework', 'net8.0'), ('targetAbi', '10.10.0.0')]:
            with self.subTest(field=field):
                invalid = copy.deepcopy(meta)
                invalid[field] = value
                with self.assertRaises(ValueError):
                    validate(invalid, project)
        with self.assertRaises(ValueError):
            validate(meta, project, 'plugin-v0.0.0.0')
