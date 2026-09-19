#!/usr/bin/env python3
"""Reject mismatched plugin build, catalog and tag versions before publishing."""
import os
from pathlib import Path
import xml.etree.ElementTree as ET

import yaml


def validate(meta, project, tag=''):
    version = project.findtext('./PropertyGroup/Version')
    framework = project.findtext('./PropertyGroup/TargetFramework')
    controller = project.find('./ItemGroup/PackageReference[@Include="Jellyfin.Controller"]')
    if meta['version'] != version:
        raise ValueError('build.yaml version must match the project Version')
    if meta['framework'] != framework:
        raise ValueError('build.yaml framework must match TargetFramework')
    if controller is None or meta['targetAbi'] != controller.attrib['Version'] + '.0':
        raise ValueError('targetAbi must match the exact Jellyfin.Controller package version')
    if tag and tag != 'plugin-v' + version:
        raise ValueError('Release tag must match the plugin version')
    return version, framework


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    meta = yaml.safe_load((root / 'build.yaml').read_text())
    project = ET.parse(root / 'Jellyfin.Plugin.Driftfin/Jellyfin.Plugin.Driftfin.csproj').getroot()
    ref = os.environ.get('GITHUB_REF', '')
    version, framework = validate(meta, project, ref.removeprefix('refs/tags/') if ref.startswith('refs/tags/') else '')
    print(f'version={version}')
    print(f'framework={framework}')
