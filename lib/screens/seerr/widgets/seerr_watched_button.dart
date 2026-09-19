import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/seerr_watched_provider.dart';
import 'package:driftfin/util/localization_helper.dart';

class SeerrWatchedButton extends ConsumerWidget {
  const SeerrWatchedButton({required this.poster, this.compact = false, super.key});

  final SeerrDashboardPosterModel poster;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = seerrWatchedProvider((
      mediaType: poster.type.name,
      tmdbId: poster.tmdbId,
      jellyfinItemId: poster.jellyfinItemId,
    ));
    final state = ref.watch(provider);
    final watched = state.value ?? false;
    final label = state.hasError
        ? context.localized.retry
        : watched
        ? context.localized.markAsUnwatched
        : context.localized.markAsWatched;
    final icon = state.isLoading
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(
            state.hasError
                ? Icons.refresh
                : watched
                ? Icons.visibility
                : Icons.visibility_outlined,
          );

    Future<void> onPressed() async {
      if (state.hasError) {
        ref.invalidate(provider);
        return;
      }
      try {
        await ref.read(provider.notifier).setWatched(!watched);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localized.somethingWentWrong)));
        }
      }
    }

    final localOnly = poster.jellyfinItemId?.isNotEmpty != true;
    if (compact) {
      return IconButton.filledTonal(
        tooltip: localOnly ? '$label · ${context.localized.settingsStaysOnDevice}' : label,
        onPressed: state.isLoading ? null : onPressed,
        icon: icon,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(onPressed: state.isLoading ? null : onPressed, icon: icon, label: Text(label)),
        if (localOnly) Text(context.localized.settingsStaysOnDevice, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
