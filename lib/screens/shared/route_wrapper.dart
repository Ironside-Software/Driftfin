import 'package:flutter/material.dart';

import 'package:driftfin/models/settings/client_settings_model.dart';
import 'package:driftfin/screens/shared/driftfin_notification_overlay.dart';
import 'package:driftfin/screens/shared/global_hotkeys.dart';

class RouteWrapper extends StatelessWidget {
  final Widget child;
  const RouteWrapper({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationManagerInitializer(
      child: GlobalHotkeys(
        child: child,
        enabledHotkeys: {
          GlobalHotKeys.closeWindow,
          GlobalHotKeys.exit,
        },
      ),
    );
  }
}
