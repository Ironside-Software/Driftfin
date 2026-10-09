# Secondary subtitles

Add an independent secondary subtitle picker to the existing subtitle dialog. Default it to Off and reset it whenever a video or backend is loaded. Prevent selecting the primary track twice. Unsupported backends show a disabled entry explaining that libmpv is required.

Use libmpv's `secondary-sid` for embedded subtitles and `sub-add ... auto` for external subtitles, without changing the primary track. Resolve the real mpv track ID rather than using a Jellyfin stream index. Keep native libass rendering; when libass is off, render the two media_kit subtitle text slots separately (primary below, secondary above).

Validation: unit tests for track selection, external subtitle reuse, disabling, capability gating and state reset; widget tests for selection and separated overlay text. Run pinned Flutter tests, analysis, and 120-column Dart formatting. No new dependency or persisted subtitle preference.
