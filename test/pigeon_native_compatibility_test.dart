import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const nativeRoot = 'android/app/src/main/kotlin/io/github/hamadtheironside/driftfin';

  test('Android bridges retain callback signatures used by native callers', () {
    for (final file in ['api/VideoPlayerHelper.g.kt', 'api/TranslationsPigeon.g.kt', 'wallpaper/WallpaperApi.g.kt']) {
      final source = File('$nativeRoot/$file').readAsStringSync();
      expect(source, isNot(contains('suspend fun ')), reason: file);
      expect(source, contains('callback: (Result<'), reason: file);
    }
  });

  test('macOS menu bridge retains completion handlers used by AppDelegate', () {
    final source = File('macos/Runner/ApplicationMenu.g.swift').readAsStringSync();
    expect(source, contains('func openNewWindow(completion:'));
    expect(source, contains('func newInstance(completion:'));
  });

  test('wallpaper bridge defines its error type in its own Kotlin package', () {
    final source = File('$nativeRoot/wallpaper/WallpaperApi.g.kt').readAsStringSync();
    expect(source, contains('package io.github.hamadtheironside.driftfin.wallpaper'));
    expect(source, contains('class FlutterError'));
    expect(
      File('$nativeRoot/wallpaper/WallpaperApiUtility.kt').readAsStringSync(),
      isNot(contains('import FlutterError')),
    );
  });
}
