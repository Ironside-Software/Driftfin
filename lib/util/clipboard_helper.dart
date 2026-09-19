import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:driftfin/screens/shared/driftfin_notification_overlay.dart';
import 'package:driftfin/util/localization_helper.dart';

extension ClipboardHelper on BuildContext {
  Future<void> copyToClipboard(String value, {String? customMessage}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      DriftfinSnack.show(
        customMessage ?? localized.copiedToClipboard,
        context: this,
      );
    }
  }
}
