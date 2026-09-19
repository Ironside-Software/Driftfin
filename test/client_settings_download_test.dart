import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/screens/settings/client_sections/client_settings_download.dart';

void main() {
  group('smartDownloadBudgetFieldText', () {
    test('empty when there is no budget', () {
      expect(smartDownloadBudgetFieldText(null), '');
    });

    test('renders whole megabytes for a set budget', () {
      expect(smartDownloadBudgetFieldText(500 * 1024 * 1024), '500');
    });

    test('truncates towards zero for a budget that is not a whole MB', () {
      expect(smartDownloadBudgetFieldText(1024 * 1024 + 500), '1');
    });
  });

  group('smartDownloadBudgetBytesFromMb', () {
    test('null (no budget) when the field is empty/cleared', () {
      expect(smartDownloadBudgetBytesFromMb(null), isNull);
    });

    test('converts megabytes to bytes', () {
      expect(smartDownloadBudgetBytesFromMb(500), 500 * 1024 * 1024);
    });

    test('round-trips through smartDownloadBudgetFieldText', () {
      final bytes = smartDownloadBudgetBytesFromMb(250);
      expect(smartDownloadBudgetFieldText(bytes), '250');
    });
  });
}
