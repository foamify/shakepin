# Changelog

Certain changes to ShakePin will probably be documented in this file.

## [0.4.1] - 2026-01-28

### Added
- Archive password protection with AES-256 encryption
- Password field in archive settings UI with dynamic encryption notice
- Auto-find button in native macOS settings to automatically detect CLI tool paths in system PATH
- Tool path caching to avoid repeated settings calls
- Parallel tool checking for better performance
- Debouncing for settings changes and app mode switches
- Debug logging for CLI availability service and settings changes
- Encryption notice showing "AES-256 if 7-Zip installed, otherwise PKZip"

### Changed
- Archives now use source file/folder name instead of generic "archive"
- Refactored CLI tool detection service with improved performance
- Archive window size increased to accommodate new password UI elements
- Updated Flutter SDK requirement to >=3.8.0-0
- Updated dependencies: meta, vector_math, test_api, leak_tracker packages

### Fixed
- Fixed 7-Zip detection to check both `7zz` and `7z` binaries on macOS
- Fixed ImageMagick detection to use `magick` binary instead of `convert`
- Fixed potential null initialization in crop_app.dart
- Improved settings change handler with `.trim()` for method names
- Fixed unbounded constraints issue in main_drop_app.dart by removing nested SingleChildScrollView wrappers

### Security
- Use AES-256 encryption (via 7zz) when available, falls back to PKZip 2.0 for compatibility

### Technical
- Added proper error handling to prevent crashes in CLI tool detection
- Added `isChecking` flag to prevent overlapping tool availability checks
- Improved tool path refresh logic with parallel Future.wait for better performance
- Added retry trigger mechanism for minify, archive, and misc operations
- Consolidated error handling into ErrorHandler widget
