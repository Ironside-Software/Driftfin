import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/connectivity_provider.dart' as network;
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/util/localization_helper.dart';

class ServerConnectionTile extends ConsumerWidget {
  const ServerConnectionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(network.offlineStateProvider);
    final url = ref.watch(serverUrlProvider) ?? '';
    final localUrl = ref.watch(userProvider.select((user) => user?.credentials.localUrl));
    final local = localUrl?.isNotEmpty == true && url == normalizeUrl(localUrl!);
    final status = offline
        ? context.localized.unableToConnectHost
        : local
        ? context.localized.settingsLocalUrlTitle
        : context.localized.server;
    return SettingsListTile(
      label: Text('${context.localized.server} (${context.localized.active})'),
      subLabel: Text(offline ? status : '$status\n$url'),
    );
  }
}
