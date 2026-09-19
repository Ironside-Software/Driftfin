import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:driftfin/providers/video_player_provider.dart';

/// Pauses playback after a chosen delay. `state` is the remaining time, or null
/// when no timer is running (drives the countdown shown in the options sheet).
final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, Duration?>((ref) => SleepTimerNotifier(ref));

class SleepTimerNotifier extends StateNotifier<Duration?> {
  SleepTimerNotifier(this.ref) : super(null);

  final Ref ref;
  Timer? _timer;

  void startMinutes(int minutes) => _start(Duration(minutes: minutes));

  /// Stop when the current item is due to finish.
  // ponytail: snapshots remaining at start; seeking mid-timer won't re-adjust.
  void startEndOfEpisode() {
    final last = ref.read(videoPlayerProvider).lastState;
    final remaining = (last?.duration ?? Duration.zero) - (last?.position ?? Duration.zero);
    if (remaining > Duration.zero) _start(remaining);
  }

  void _start(Duration duration) {
    _timer?.cancel();
    state = duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Player closed out from under us — drop the timer, nothing to pause.
      if (ref.read(playBackModel) == null) {
        cancel();
        return;
      }
      final next = (state ?? Duration.zero) - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        cancel();
        ref.read(videoPlayerProvider).pause();
      } else {
        state = next;
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
