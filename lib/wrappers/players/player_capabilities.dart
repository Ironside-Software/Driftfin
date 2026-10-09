/// Declares which optional playback features a [BasePlayer] backend actually
/// supports, so UI can honestly gray out a control instead of it silently
/// no-oping (e.g. a "Night-Mode Audio" toggle on Android TV's ExoPlayer path).
///
/// Every backend must report a complete, explicit set - there is no
/// backend-agnostic default - so adding a new capability forces every
/// implementation to make a deliberate choice about it.
class PlayerCapabilities {
  /// Can capture the current video frame as an image (freeze-frame export).
  final bool screenshots;

  /// Supports a live audio filter chain (dialogue boost, downmix, ReplayGain).
  final bool audioDsp;

  /// Can sample frames continuously enough to drive an ambient glow effect.
  final bool ambientGlow;

  /// Supports per-title zoom/pan overrides on the video output.
  final bool perTitleZoomPan;

  /// Surfaces playback errors on [PlayerState] instead of swallowing them.
  final bool errorReporting;

  /// Supports shifting subtitle timing independently of the audio track.
  final bool subtitleDelay;

  /// Supports a gapless crossfade between two tracks/streams.
  final bool crossfade;

  /// Supports displaying an independently selected second subtitle track.
  final bool secondarySubtitles;

  const PlayerCapabilities({
    this.screenshots = false,
    this.audioDsp = false,
    this.ambientGlow = false,
    this.perTitleZoomPan = false,
    this.errorReporting = false,
    this.subtitleDelay = false,
    this.crossfade = false,
    this.secondarySubtitles = false,
  });

  /// A backend that supports none of the optional capabilities.
  static const PlayerCapabilities none = PlayerCapabilities();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerCapabilities &&
          runtimeType == other.runtimeType &&
          screenshots == other.screenshots &&
          audioDsp == other.audioDsp &&
          ambientGlow == other.ambientGlow &&
          perTitleZoomPan == other.perTitleZoomPan &&
          errorReporting == other.errorReporting &&
          subtitleDelay == other.subtitleDelay &&
          crossfade == other.crossfade &&
          secondarySubtitles == other.secondarySubtitles;

  @override
  int get hashCode => Object.hash(
    screenshots,
    audioDsp,
    ambientGlow,
    perTitleZoomPan,
    errorReporting,
    subtitleDelay,
    crossfade,
    secondarySubtitles,
  );

  @override
  String toString() =>
      'PlayerCapabilities(screenshots: $screenshots, audioDsp: $audioDsp, '
      'ambientGlow: $ambientGlow, perTitleZoomPan: $perTitleZoomPan, '
      'errorReporting: $errorReporting, subtitleDelay: $subtitleDelay, crossfade: $crossfade, secondarySubtitles: $secondarySubtitles)';
}
