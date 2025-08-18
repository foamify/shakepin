# ShakePin Dart Files Audit & TODO Plan

This document lists every .dart file in the project and outlines an initial TODO checklist per file. We will refine and execute these TODOs in subsequent steps.

Legend: [ ] pending, [x] done, [~] in-progress

## Core App Files

### lib/main.dart
- [ ] Ensure main() initializes Flutter bindings and SharedPreferences safely
- [ ] Centralize theme and adaptive platform visuals
- [ ] Route management: verify navigation entry points
- [ ] Error handling: add Zone error handler and FlutterError.onError
- [ ] Review flavor handling (oss vs appStore)

### lib/state.dart
- [ ] Convert loose ValueNotifiers to a structured AppState class
- [ ] Encapsulate global state mutations via methods
- [ ] Document AppMode and compatibility checks thoroughly
- [ ] Persist key preferences (output directory, last mode)
- [ ] Add unit tests for AppMode.isFileCompatible

### lib/oss_licenses.dart
- [ ] Verify assets linkage and loading performance
- [ ] Lazy-load or paginate license list if large
- [ ] Improve search/filter within licenses

### lib/drop_target.dart
- [ ] Consolidate with widgets/drop_target.dart or rename to avoid confusion
- [ ] Ensure platform-specific paths and drag types are handled
- [ ] Add tests for URL vs file path drops

## App Scenes

### lib/app/about_app.dart
- [ ] Polish layout, typography and branding
- [ ] Add app version and build info dynamically
- [ ] Link to website, privacy policy, and support

### lib/app/crop_app.dart
- [ ] Validate image loading and bounds
- [ ] Ensure high-DPI handling on macOS/Windows
- [ ] Export options: format and quality settings

### lib/app/license_app.dart
- [ ] Reuse oss_licenses functionality where feasible
- [ ] Add search/filter UI and copy-to-clipboard

### lib/app/setup_app.dart
- [ ] Streamline setup steps and error reporting
- [ ] Add retry and detailed logs
- [ ] Persist successful setup to skip next launch

### lib/app/main_drop_app.dart
- [ ] Review main layout resilience to window resizing
- [ ] Keyboard shortcuts and accessibility
- [ ] Ensure drag-over states are visually distinct

## Main Drop Area

### lib/app/main_drop/custom_drag_gesture.dart
- [ ] Ensure gesture recognizers don’t conflict with native drag/drop
- [ ] Add test coverage for gesture edge cases

### lib/app/main_drop/drop_section.dart
- [ ] Separate presentation and logic (extract controller)
- [ ] Improve empty state and error states

### lib/app/main_drop/dropped_item.dart
- [ ] Define a strong model for dropped items (file, URL, metadata)
- [ ] Add validation and normalization utilities

### lib/app/main_drop/main_sidebar.dart
- [ ] Confirm AppMode switching UX and visual feedback
- [ ] Add tooltips and keyboard hints

## Sections: Archive

### lib/app/sections/archive_section/archive_section.dart
- [ ] Clarify responsibilities and move logic to service layer
- [ ] Better progress reporting and cancelation
- [ ] Handle large file batches efficiently

### lib/app/sections/archive_section/archive_settings.dart
- [ ] Validate inputs (output path, compression level)
- [ ] Save/restore default options
- [ ] Add presets and tooltips

## Sections: Minify

### lib/app/sections/minify_section/minify_section.dart
- [ ] Refactor UI state to a dedicated ChangeNotifier or Riverpod
- [ ] Clear status updates for per-file results
- [ ] Accessible sliders/inputs with labels

### lib/app/sections/minify_section/minify_settings.dart
- [ ] Extract ffmpeg invocation builder and validate args
- [ ] Sanitize user-provided values
- [ ] Add presets (web optimized, high quality, smallest size)
- [ ] Surface estimated output size where possible

### lib/app/sections/minify_section/minify_state.dart
- [ ] Consolidate state mutations
- [ ] Add unit tests for minify pipeline
- [ ] Debounce operations and queue management

## Sections: Misc

### lib/app/sections/misc_section/misc_section.dart
- [ ] Organize cards/actions with consistent patterns
- [ ] Add clear descriptions and warnings if destructive

### lib/app/sections/misc_section/misc_settings.dart
- [ ] Centralize settings schema and validation
- [ ] Add import/export settings

## Utils

### lib/utils/analytics.dart
- [ ] Make analytics opt-in and anonymized
- [ ] Wrap behind interface with no-ops for oss flavor

### lib/utils/cli.dart
- [ ] Provide a safe, cross-platform process runner with timeouts
- [ ] Normalize PATH and dependencies checks (ffmpeg, 7z, yt-dlp)
- [ ] Structured logs and error parsing

### lib/utils/cli/archive.dart
- [ ] Validate compression tool availability
- [ ] Support zip/7z/tar.gz with strategy pattern
- [ ] Add progress parsing and cancellation hooks

### lib/utils/cli/convert_to_gif.dart
- [ ] Validate input formats and fps controls
- [ ] Provide palette optimization for better quality/size

### lib/utils/cli/convert_to_ico.dart
- [ ] Multi-size ICO generation with sharp/ffmpeg pipeline
- [ ] Validate square inputs and resizing strategy

### lib/utils/cli/download_media.dart
- [ ] Dependency detection (yt-dlp/ffmpeg)
- [ ] Retry/backoff and resume
- [ ] Sanitize filenames and support playlists

### lib/utils/cli/download_video.dart
- [ ] Quality presets and container selection
- [ ] Progress aggregation and cancellation

### lib/utils/cli/extract_audio.dart
- [ ] Format selection (mp3/aac/wav) with bitrate controls
- [ ] Handle video inputs and copy codecs when possible

### lib/utils/cli/minify_image.dart
- [ ] Choose codecs per input (png/jpeg/webp/avif)
- [ ] Preserve metadata options

### lib/utils/cli/minify_video.dart
- [ ] CRF/bitrate presets and 2-pass options
- [ ] Hardware acceleration detection (VideoToolbox/NVENC)

### lib/utils/cli/setup.dart
- [ ] Check and bootstrap external dependencies
- [ ] Provide actionable remediation steps

### lib/utils/cli/video_utils.dart
- [ ] Probe media info (duration, codecs) with robust parsing
- [ ] Utility for safe temp file handling

### lib/utils/drop_channel.dart
- [ ] Document native channel methods and error cases
- [ ] Add type-safe wrappers and unit tests (mock channel)

### lib/utils/handle_menu_item.dart
- [ ] Centralize app menu handling and keyboard shortcuts
- [ ] Ensure platform-consistent behavior

### lib/utils/license_service.dart
- [ ] Cache parsed licenses
- [ ] Add fallback when assets missing

### lib/utils/logger.dart
- [ ] Replace prints with structured logging facade
- [ ] Add log levels, file logging toggle

### lib/utils/utils.dart
- [ ] Consolidate path/url/file helpers
- [ ] Add unit tests and docs

## Widgets

### lib/widgets/curved_scrollbar.dart
- [ ] Ensure accessibility and hit testing
- [ ] Respect platform scroll behaviors

### lib/widgets/double_slider.dart
- [ ] Keyboard accessibility and labeled values
- [ ] Validate min/max and snapping

### lib/widgets/drag_to_move_area.dart
- [ ] Test on macOS/Windows for titlebar behavior
- [ ] Avoid gesture conflicts

### lib/widgets/drop_button_hover.dart
- [ ] Provide high-contrast focus states
- [ ] Respect reduced motion settings

### lib/widgets/drop_hover_widget.dart
- [ ] Clear drag-over visual feedback
- [ ] Test with multiple file types

### lib/widgets/drop_target.dart
- [ ] Unify with root drop_target or clarify naming
- [ ] Ensure event throttling and debouncing

### lib/widgets/file_image_widget.dart
- [ ] Placeholder and error states
- [ ] Cache management

### lib/widgets/glass_button.dart
- [ ] Contrast and readability checks
- [ ] Hover/pressed animations

### lib/widgets/multi_hit_stack.dart
- [ ] Document hit testing behavior
- [ ] Add unit tests

### lib/widgets/native_dropdown_button.dart
- [ ] Keyboard navigation and screen reader labels
- [ ] Ensure native feel on macOS/Windows

### lib/widgets/native_tooltip.dart
- [ ] Delay, position, and accessibility
- [ ] Respect platform conventions

### lib/widgets/side_button.dart
- [ ] Icon + label alignment and tooltips
- [ ] Focus ring and keyboard interactions

### lib/widgets/support_banner.dart
- [ ] Make the banner optional and configurable
- [ ] Avoid brand hardcoding; move to config
- [ ] Animation performance check

### lib/widgets/transparent_pointer.dart
- [ ] Document pointer behavior
- [ ] Verify with nested gesture detectors

## App Sections Index

### lib/app/sections/misc_section/misc_section.dart
- [ ] Ensure consistency with other sections
- [ ] Extract shared components

### lib/app/sections/misc_section/misc_settings.dart
- [ ] Validate settings and add defaults
- [ ] Ensure state persistence

## Additional Notes
- [ ] Plan and implement a beautiful native macOS Settings window using Swift/SwiftUI integrated via Flutter platform channels or Flutter macOS plugin structure.
- [ ] Settings window should include tabs: General, Paths, Minify, Archive, Misc.
- [ ] Expose Swift-side window as NSWindow with NSWindowController, shown from Flutter via a MethodChannel.
- [ ] Persist settings with UserDefaults and sync with SharedPreferences in Flutter.
- [ ] Ensure bi-directional sync and live updates.