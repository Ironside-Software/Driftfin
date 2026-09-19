import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  group('ClientSettingsNotifier.setEnableCrashReporting', () {
    test('is off by default', () {
      expect(container.read(clientSettingsProvider).enableCrashReporting, isFalse);
    });

    test('turns the flag on and off', () {
      final notifier = container.read(clientSettingsProvider.notifier);

      notifier.setEnableCrashReporting(true);
      expect(container.read(clientSettingsProvider).enableCrashReporting, isTrue);

      notifier.setEnableCrashReporting(false);
      expect(container.read(clientSettingsProvider).enableCrashReporting, isFalse);
    });
  });

  group('ClientSettingsNotifier.setSmartDownloadBudget', () {
    test('has no budget by default', () {
      expect(container.read(clientSettingsProvider).smartDownloadBudgetBytes, isNull);
    });

    test('sets a positive budget', () {
      final notifier = container.read(clientSettingsProvider.notifier);

      notifier.setSmartDownloadBudget(1024);
      expect(container.read(clientSettingsProvider).smartDownloadBudgetBytes, 1024);
    });

    test('treats null and non-positive values as "no budget"', () {
      final notifier = container.read(clientSettingsProvider.notifier);

      notifier.setSmartDownloadBudget(1024);
      notifier.setSmartDownloadBudget(0);
      expect(container.read(clientSettingsProvider).smartDownloadBudgetBytes, isNull);

      notifier.setSmartDownloadBudget(1024);
      notifier.setSmartDownloadBudget(-5);
      expect(container.read(clientSettingsProvider).smartDownloadBudgetBytes, isNull);

      notifier.setSmartDownloadBudget(1024);
      notifier.setSmartDownloadBudget(null);
      expect(container.read(clientSettingsProvider).smartDownloadBudgetBytes, isNull);
    });
  });
}
