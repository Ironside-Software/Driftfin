import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import 'package:driftfin/screens/shared/default_alert_dialog.dart';
import 'package:driftfin/screens/shared/driftfin_notification_overlay.dart';
import 'package:driftfin/util/localization_helper.dart';

Future<bool> closeCurrentWindow() async {
  final manager = WindowManager.instance;

  if (!await manager.isClosable()) {
    return false;
  }

  await manager.close();
  return true;
}

Future<void> quitApplication(BuildContext context) async {
  if (kIsWeb) {
    return;
  }

  final windows = await WindowController.getAll();
  if (!context.mounted) {
    return;
  }

  if (windows.length > 1) {
    await showDefaultAlertDialog(
      context,
      context.localized.exitDriftfinTitle,
      context.localized.quitMultipleWindowsDesc(windows.length),
      (context) => SystemNavigator.pop(),
      context.localized.exit,
      (context) => Navigator.of(context).pop(),
      context.localized.cancel,
    );
    return;
  }

  final closed = await closeCurrentWindow();
  if (!closed && context.mounted) {
    DriftfinSnack.show(context.localized.somethingWentWrong, context: context);
  }
}
