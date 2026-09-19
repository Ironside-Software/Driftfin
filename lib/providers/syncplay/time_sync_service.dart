import 'dart:async';

/// One clock-offset measurement.
class _TimeSample {
  const _TimeSample(this.offset, this.roundTrip);
  final Duration offset; // server clock - local clock
  final Duration roundTrip;
}

/// A single round-trip UTC measurement from the server.
class UtcMeasurement {
  const UtcMeasurement({required this.requestReceived, required this.responseSent});
  final DateTime requestReceived; // server clock when it got our request
  final DateTime responseSent; // server clock when it replied
}

/// Estimates the offset between the local clock and the Jellyfin server clock
/// using the standard NTP four-timestamp formula, so SyncPlay's server-relative
/// `When` execution timestamps can be converted to local time.
///
/// Cadence mirrors reference clients: a few fast samples to converge quickly,
/// then a low-frequency keep-fresh ping. The best (lowest round-trip) sample in
/// a sliding window is used, which rejects offset noise from jittery requests.
class TimeSyncService {
  TimeSyncService({
    required this._fetchUtc,
    this.onPing,
    this.windowSize = 8,
    this.fastSamples = 3,
    this.fastInterval = const Duration(seconds: 1),
    this.slowInterval = const Duration(seconds: 60),
  });

  final Future<UtcMeasurement?> Function() _fetchUtc;

  /// Reports the measured one-way delay (ping, ms) so the caller can forward it
  /// to the server's `/SyncPlay/Ping` for its own scheduling math.
  final void Function(int pingMs)? onPing;

  final int windowSize;
  final int fastSamples;
  final Duration fastInterval;
  final Duration slowInterval;

  final List<_TimeSample> _samples = [];
  Timer? _timer;
  bool _disposed = false;
  int _completedSamples = 0;

  bool get hasSynced => _samples.isNotEmpty;

  /// Best estimate of (server clock - local clock).
  Duration get offset {
    if (_samples.isEmpty) return Duration.zero;
    // Lowest round-trip ⇒ least asymmetry ⇒ most trustworthy offset.
    return _samples.reduce((a, b) => a.roundTrip <= b.roundTrip ? a : b).offset;
  }

  /// Convert a server-clock timestamp (e.g. a command's `When`) to local time.
  DateTime serverToLocal(DateTime serverTime) => serverTime.toUtc().subtract(offset);

  /// Convert a local timestamp to the server clock (for Buffering/Ready `when`).
  DateTime localToServer(DateTime local) => local.toUtc().add(offset);

  void start() {
    _disposed = false;
    _completedSamples = 0;
    _timer?.cancel();
    _tick();
  }

  /// Pause sampling (e.g. when leaving a group) without discarding the learned
  /// offset; [start] resumes.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_disposed) return;
    await _sample();
    if (_disposed) return;
    _completedSamples++;
    final next = _completedSamples < fastSamples ? fastInterval : slowInterval;
    _timer?.cancel();
    _timer = Timer(next, _tick);
  }

  Future<void> _sample() async {
    final t0 = DateTime.now().toUtc();
    UtcMeasurement? m;
    try {
      m = await _fetchUtc();
    } catch (_) {
      return;
    }
    if (m == null || _disposed) return;
    final t1 = DateTime.now().toUtc();
    final tr = m.requestReceived.toUtc();
    final tt = m.responseSent.toUtc();

    // offset = ((Tr - T0) + (Tt - T1)) / 2
    final offsetMicros = (tr.difference(t0).inMicroseconds + tt.difference(t1).inMicroseconds) ~/ 2;
    // round-trip = (T1 - T0) - (Tt - Tr)
    final rttMicros = t1.difference(t0).inMicroseconds - tt.difference(tr).inMicroseconds;

    _samples.add(
      _TimeSample(Duration(microseconds: offsetMicros), Duration(microseconds: rttMicros < 0 ? 0 : rttMicros)),
    );
    if (_samples.length > windowSize) _samples.removeAt(0);

    onPing?.call((rttMicros ~/ 2 ~/ 1000).clamp(0, 60000));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _samples.clear();
  }
}
