import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'package:driftfin/theme/dynamic_color_scheme.dart';

void main() {
  test('keeps all system palette roles for light and dark themes', () {
    for (final brightness in Brightness.values) {
      final source = material.ColorScheme.fromSeed(seedColor: Colors.teal, brightness: brightness);
      final converted = fromDynamicColorScheme(source);
      expect(converted.brightness, source.brightness, reason: 'brightness');
      expect(converted.primary, source.primary, reason: 'primary');
      expect(converted.onPrimary, source.onPrimary, reason: 'onPrimary');
      expect(converted.primaryContainer, source.primaryContainer, reason: 'primaryContainer');
      expect(converted.onPrimaryContainer, source.onPrimaryContainer, reason: 'onPrimaryContainer');
      expect(converted.primaryFixed, source.primaryFixed, reason: 'primaryFixed');
      expect(converted.primaryFixedDim, source.primaryFixedDim, reason: 'primaryFixedDim');
      expect(converted.onPrimaryFixed, source.onPrimaryFixed, reason: 'onPrimaryFixed');
      expect(converted.onPrimaryFixedVariant, source.onPrimaryFixedVariant, reason: 'onPrimaryFixedVariant');
      expect(converted.secondary, source.secondary, reason: 'secondary');
      expect(converted.onSecondary, source.onSecondary, reason: 'onSecondary');
      expect(converted.secondaryContainer, source.secondaryContainer, reason: 'secondaryContainer');
      expect(converted.onSecondaryContainer, source.onSecondaryContainer, reason: 'onSecondaryContainer');
      expect(converted.secondaryFixed, source.secondaryFixed, reason: 'secondaryFixed');
      expect(converted.secondaryFixedDim, source.secondaryFixedDim, reason: 'secondaryFixedDim');
      expect(converted.onSecondaryFixed, source.onSecondaryFixed, reason: 'onSecondaryFixed');
      expect(converted.onSecondaryFixedVariant, source.onSecondaryFixedVariant, reason: 'onSecondaryFixedVariant');
      expect(converted.tertiary, source.tertiary, reason: 'tertiary');
      expect(converted.onTertiary, source.onTertiary, reason: 'onTertiary');
      expect(converted.tertiaryContainer, source.tertiaryContainer, reason: 'tertiaryContainer');
      expect(converted.onTertiaryContainer, source.onTertiaryContainer, reason: 'onTertiaryContainer');
      expect(converted.tertiaryFixed, source.tertiaryFixed, reason: 'tertiaryFixed');
      expect(converted.tertiaryFixedDim, source.tertiaryFixedDim, reason: 'tertiaryFixedDim');
      expect(converted.onTertiaryFixed, source.onTertiaryFixed, reason: 'onTertiaryFixed');
      expect(converted.onTertiaryFixedVariant, source.onTertiaryFixedVariant, reason: 'onTertiaryFixedVariant');
      expect(converted.error, source.error, reason: 'error');
      expect(converted.onError, source.onError, reason: 'onError');
      expect(converted.errorContainer, source.errorContainer, reason: 'errorContainer');
      expect(converted.onErrorContainer, source.onErrorContainer, reason: 'onErrorContainer');
      expect(converted.surface, source.surface, reason: 'surface');
      expect(converted.onSurface, source.onSurface, reason: 'onSurface');
      expect(converted.surfaceDim, source.surfaceDim, reason: 'surfaceDim');
      expect(converted.surfaceBright, source.surfaceBright, reason: 'surfaceBright');
      expect(converted.surfaceContainerLowest, source.surfaceContainerLowest, reason: 'surfaceContainerLowest');
      expect(converted.surfaceContainerLow, source.surfaceContainerLow, reason: 'surfaceContainerLow');
      expect(converted.surfaceContainer, source.surfaceContainer, reason: 'surfaceContainer');
      expect(converted.surfaceContainerHigh, source.surfaceContainerHigh, reason: 'surfaceContainerHigh');
      expect(converted.surfaceContainerHighest, source.surfaceContainerHighest, reason: 'surfaceContainerHighest');
      expect(converted.onSurfaceVariant, source.onSurfaceVariant, reason: 'onSurfaceVariant');
      expect(converted.outline, source.outline, reason: 'outline');
      expect(converted.outlineVariant, source.outlineVariant, reason: 'outlineVariant');
      expect(converted.shadow, source.shadow, reason: 'shadow');
      expect(converted.scrim, source.scrim, reason: 'scrim');
      expect(converted.inverseSurface, source.inverseSurface, reason: 'inverseSurface');
      expect(converted.onInverseSurface, source.onInverseSurface, reason: 'onInverseSurface');
      expect(converted.inversePrimary, source.inversePrimary, reason: 'inversePrimary');
      expect(converted.surfaceTint, source.surfaceTint, reason: 'surfaceTint');
    }
  });
}
