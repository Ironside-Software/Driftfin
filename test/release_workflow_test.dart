import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final workflow = loadYaml(File('.github/workflows/release.yml').readAsStringSync()) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  const platforms = ['web', 'windows', 'ios', 'android', 'macos_desktop', 'linux'];

  List<YamlMap> steps(String job) => (jobs[job]['steps'] as YamlList).cast<YamlMap>();
  String script(String job, String name) => steps(job).singleWhere((step) => step['name'] == name)['run'] as String;

  test('iOS-only dispatch skips other platforms without changing full release defaults', () {
    final input = workflow['on']['workflow_dispatch']['inputs']['ios_only'];
    expect(input['type'], 'boolean');
    expect(input['default'], isFalse);
    for (final job in platforms.where((job) => job != 'ios')) {
      expect(
        jobs[job]['if'],
        job == 'windows' ? r'${{ !inputs.ios_only }}' : r'${{ !inputs.ios_only && !inputs.windows_only }}',
        reason: job,
      );
    }
    expect(jobs['ios']['if'], r'${{ !inputs.windows_only }}');
    expect(jobs['testflight']['needs'], containsAll(['prepare', 'ios']));
  });

  test('all build jobs and Pages check out the same resolved commit', () {
    for (final job in [...platforms, 'pages']) {
      final checkout = steps(job).singleWhere((step) => '${step['uses']}'.startsWith('actions/checkout@'));
      expect(checkout['with']['ref'], r'${{ needs.prepare.outputs.sha }}', reason: job);
    }
    expect(jobs['prepare']['outputs']['sha'], r'${{ steps.v.outputs.sha }}');
    expect(workflow['concurrency']['cancel-in-progress'], isFalse);
  });

  test('publishing consumes artifacts and requires successful producers', () {
    expect(jobs['release']['needs'], containsAll(platforms));
    expect(jobs['pages']['needs'], contains('web'));
    expect(jobs['testflight']['needs'], containsAll(['prepare', 'ios']));
    for (final job in ['release', 'pages', 'testflight']) {
      expect(steps(job).any((step) => '${step['uses']}'.startsWith('actions/download-artifact@')), isTrue);
      expect(steps(job).any((step) => '${step['run']}'.contains('flutter build')), isFalse);
      expect('${jobs[job]['if']}', isNot(contains('always()')));
    }
    for (final job in ['release', 'pages']) {
      expect(jobs[job]['if'], contains("github.event_name == 'push'"));
    }
    expect(jobs['testflight']['if'], "needs.prepare.outputs.testflight == 'true'");
    for (final job in platforms) {
      final upload = steps(job).singleWhere((step) => '${step['uses']}'.startsWith('actions/upload-artifact@'));
      expect(upload['with']['if-no-files-found'], 'error', reason: job);
    }
  });

  test('iOS chooses one build and Android builds both modes independently', () {
    final iosBuilds = steps('ios').where((step) => '${step['run']}'.contains('flutter build')).toList();
    expect(iosBuilds, hasLength(2));
    expect(
      iosBuilds.map((step) => step['if']),
      unorderedEquals(["needs.prepare.outputs.signed_ios == 'true'", "needs.prepare.outputs.signed_ios != 'true'"]),
    );
    expect(jobs['android']['strategy']['matrix']['mode'], unorderedEquals(['release', 'debug']));
    expect(jobs['android']['strategy']['fail-fast'], isFalse);
  });

  test('tag releases and opt-in manual runs sign and upload the same iOS artifact', () {
    expect(jobs['prepare']['outputs']['testflight'], r"${{ github.event_name == 'push' || inputs.testflight }}");
    expect(workflow['on']['push']['tags'], ['v*']);
    expect(workflow['on']['workflow_dispatch']['inputs']['testflight']['default'], isFalse);
    expect(jobs['ios']['environment'], r"${{ needs.prepare.outputs.signed_ios == 'true' && 'testflight' || '' }}");
    for (final name in [
      'Import App Store distribution certificate',
      'Download App Store provisioning profile',
      'Build signed production IPA',
      'Collect signed IPA',
    ]) {
      expect(
        steps('ios').singleWhere((step) => step['name'] == name)['if'],
        "needs.prepare.outputs.signed_ios == 'true'",
        reason: name,
      );
    }
    final download = steps('testflight')
        .singleWhere((step) => '${step['uses']}'.startsWith('actions/download-artifact@'));
    expect(download['with']['name'], 'ios');
    final upload = steps('testflight').singleWhere((step) => step['name'] == 'Upload to TestFlight');
    // App Store Connect rejects updating this immutable value once it is set by the IPA.
    expect(upload['with'].containsKey('uses-non-exempt-encryption'), isFalse);
  });

  test('signed verification never implies TestFlight upload', () {
    final inputs = workflow['on']['workflow_dispatch']['inputs'];
    expect(inputs['sign_ios']['default'], isFalse);
    expect(inputs['windows_only']['default'], isFalse);
    expect(
      jobs['prepare']['outputs']['signed_ios'],
      r"${{ github.event_name == 'push' || inputs.testflight || inputs.sign_ios }}",
    );
    expect(jobs['prepare']['outputs']['testflight'], isNot(contains('sign_ios')));
    expect(jobs['testflight']['if'], "needs.prepare.outputs.testflight == 'true'");
    expect(
      steps('prepare').first['if'],
      'inputs.windows_only && (inputs.ios_only || inputs.testflight || inputs.sign_ios)',
    );
    expect(
      script('windows', 'Verify Windows integration and search UI'),
      contains('test/unified_search_widget_test.dart'),
    );
    expect(
      script('windows', 'Verify Windows integration and search UI'),
      contains('test/seerr_request_permissions_test.dart'),
    );
  });

  group('Unix runner scripts', () {
    test('iOS bundle declares the camera purpose required by the bundled MDK library', () async {
      final result = await Process.run('python3', [
        '-c',
        '''
import plistlib
with open('ios/Runner/Info.plist', 'rb') as source:
    info = plistlib.load(source)
purpose = info.get('NSCameraUsageDescription')
assert isinstance(purpose, str) and purpose.strip(), 'Missing camera purpose string'
assert 'does not need camera access' in purpose, 'Do not claim an unused camera feature'
assert info.get('ITSAppUsesNonExemptEncryption') is False, 'Declare encryption compliance in the IPA'
''',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    });

    test('version metadata distinguishes pushed tags from manual builds', () async {
      final temp = Directory.systemTemp.createTempSync('driftfin-version-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final output = File('${temp.path}/output');
      final prepare = steps('prepare').singleWhere((step) => step['id'] == 'v')['run'] as String;
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final version = '${pubspec['version']}'.split('+').first;
      final sha = (await Process.run('git', ['rev-parse', 'HEAD'])).stdout.toString().trim();
      for (final event in ['push', 'workflow_dispatch']) {
        output.writeAsStringSync('');
        final result = await Process.run(
          'bash',
          ['-e', '-c', prepare],
          environment: {
            'GITHUB_EVENT_NAME': event,
            'GITHUB_REF': 'refs/tags/v1.2.3-nightly.20260919.1',
            'GITHUB_REF_NAME': 'v1.2.3-nightly.20260919.1',
            'GITHUB_OUTPUT': output.path,
          },
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(output.readAsStringSync(), contains('sha=$sha\n'));
        expect(
          output.readAsStringSync(),
          contains('version=${event == 'push' ? '1.2.3-nightly.20260919.1' : '$version-dev'}\n'),
        );
      }
    });

    test('Pages rebases the downloaded bundle and preserves its other files', () async {
      final temp = Directory.systemTemp.createTempSync('driftfin-pages-');
      addTearDown(() => temp.deleteSync(recursive: true));
      Directory('${temp.path}/site').createSync();
      File('${temp.path}/site/index.html').writeAsStringSync('landing page');
      Directory('${temp.path}/bundle').createSync();
      final html = File('web/index.html').readAsStringSync().replaceAll(r'$FLUTTER_BASE_HREF', '/');
      File('${temp.path}/bundle/index.html').writeAsStringSync(html);
      File('${temp.path}/bundle/main.dart.js').writeAsStringSync('compiled app');
      Directory('${temp.path}/dist').createSync();
      final zip = await Process.run('python3', [
        '-c',
        'import shutil; shutil.make_archive("../dist/Driftfin-Web-test", "zip", ".")',
      ], workingDirectory: '${temp.path}/bundle');
      expect(zip.exitCode, 0, reason: '${zip.stderr}');
      final assemble = script(
        'pages',
        'Assemble Pages site from the web build',
      ).replaceAll(r'${{ needs.prepare.outputs.version }}', 'test');
      final result = await Process.run('bash', ['-e', '-c', assemble], workingDirectory: temp.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(File('${temp.path}/dist-pages/index.html').readAsStringSync(), 'landing page');
      expect(
        File('${temp.path}/dist-pages/app/index.html').readAsStringSync(),
        html.replaceAll('href="/"', 'href="/Driftfin/app/"'),
      );
      expect(File('${temp.path}/dist-pages/app/main.dart.js').readAsStringSync(), 'compiled app');
      expect(File('${temp.path}/bundle/index.html').readAsStringSync(), html);
    });

    for (final mode in ['release', 'debug']) {
      test('Android $mode packaging keeps every ABI and fails on missing APKs', () async {
        final temp = Directory.systemTemp.createTempSync('driftfin-apk-');
        addTearDown(() => temp.deleteSync(recursive: true));
        final input = Directory('${temp.path}/build/app/outputs/flutter-apk')..createSync(recursive: true);
        const abis = ['armeabi-v7a', 'arm64-v8a', 'x86_64'];
        for (final abi in abis) {
          File('${input.path}/app-$abi-production-$mode.apk').writeAsStringSync(abi);
        }
        final collect = script('android', 'Collect APKs').replaceAll(r'${{ needs.prepare.outputs.version }}', 'test');
        Future<ProcessResult> run() =>
            Process.run('bash', ['-e', '-c', collect], workingDirectory: temp.path, environment: {'BUILD_MODE': mode});
        final result = await run();
        expect(result.exitCode, 0, reason: '${result.stderr}');
        for (final abi in abis) {
          final suffix = mode == 'debug' ? '-debug' : '';
          expect(File('${temp.path}/dist-apk/Driftfin-Android-test-$abi$suffix.apk').readAsStringSync(), abi);
        }
        File('${input.path}/app-x86_64-production-$mode.apk').deleteSync();
        expect((await run()).exitCode, isNot(0));
      });
    }
  }, skip: Platform.isWindows ? 'Release scripts run on Unix CI runners.' : false);
}
