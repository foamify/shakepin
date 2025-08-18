import 'package:url_launcher/url_launcher.dart';

/// Centralized utility for handling CLI tool installation and error detection
class CliToolHelper {
  /// Supported CLI tools with their installation URLs
  static const Map<String, String> _toolInstallationUrls = {
    // 'ffmpeg': 'https://ffmpeg.org/download.html',
    'ffmpeg': 'https://www.youtube.com/watch?v=kXzcR_HRgV8',
    'gallery-dl': 'https://github.com/mikf/gallery-dl#homebrew',
    'gifski': 'https://formulae.brew.sh/formula/gifski',
    'yt-dlp': 'https://formulae.brew.sh/formula/yt-dlp',
    '7z': 'https://formulae.brew.sh/formula/sevenzip',
    'imagemagick': 'https://imagemagick.org/script/download.php#macos',
  };

  /// Tool name patterns for error detection based on actual system error messages
  static const Map<String, List<String>> _toolErrorPatterns = {
    // FFmpeg patterns - actual shell error: "zsh:1: command not found: ffmpeg"
     // ProcessException: "No such file or directory" when command doesn't exist
     'ffmpeg': [
       'command not found: ffmpeg',
       'command not found: ffprobe',
       'ProcessException: No such file or directory\n  Command: ffmpeg',
       'ProcessException: No such file or directory\n  Command: ffprobe',
       'ffmpeg',
       'ffprobe',
       'FFmpeg is not installed',
       'not found in PATH'
     ],
    // ImageMagick patterns - commands: magick, convert
     'imagemagick': [
       'command not found: magick',
       'command not found: convert',
       'ProcessException: No such file or directory\n  Command: magick',
       'ProcessException: No such file or directory\n  Command: convert',
       'magick',
       'convert',
       'imagemagick'
     ],
     // yt-dlp patterns - actual shell error: "zsh:1: command not found: yt-dlp"
     'yt-dlp': [
       'command not found: yt-dlp',
       'ProcessException: No such file or directory\n  Command: yt-dlp',
       'yt-dlp',
       'yt_dlp',
       'youtube-dl'
     ],
     // gallery-dl patterns - actual shell error: "zsh:1: command not found: gallery-dl"
     'gallery-dl': [
       'command not found: gallery-dl',
       'ProcessException: No such file or directory\n  Command: gallery-dl',
       'gallery-dl',
       'gallery_dl'
     ],
     // gifski patterns - actual shell error: "zsh:1: command not found: gifski"
     'gifski': [
       'command not found: gifski',
       'ProcessException: No such file or directory\n  Command: gifski',
       'gifski'
     ],
     // 7z patterns - actual shell error: "zsh:1: command not found: 7z"
     '7z': [
       'command not found: 7z',
       'command not found: 7zz',
       'ProcessException: No such file or directory\n  Command: 7z',
       'ProcessException: No such file or directory\n  Command: 7zz',
       '7z',
       '7zz',
       '7zip',
       'sevenzip'
     ],
  };

  /// Detect which CLI tool is missing based on error message
  static String? detectMissingTool(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    for (final entry in _toolErrorPatterns.entries) {
      final toolName = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        if (lowerError.contains(pattern.toLowerCase())) {
          return toolName;
        }
      }
    }

    return null;
  }

  /// Detect missing tool from a list of error messages
  static String? detectMissingToolFromErrors(List<String> errors) {
    for (final error in errors) {
      final tool = detectMissingTool(error);
      if (tool != null) return tool;
    }
    return null;
  }

  /// Get installation URL for a specific tool
  static String? getInstallationUrl(String toolName) {
    return _toolInstallationUrls[toolName.toLowerCase()];
  }

  /// Get user-friendly tool name for display
  static String getDisplayName(String toolName) {
    switch (toolName.toLowerCase()) {
      case 'ffmpeg':
        return 'FFmpeg';
      case 'gallery-dl':
        return 'gallery-dl';
      case 'gifski':
        return 'Gifski';
      case 'yt-dlp':
        return 'yt-dlp';
      case '7z':
        return '7-Zip';
      case 'imagemagick':
        return 'ImageMagick';
      default:
        return toolName;
    }
  }

  /// Open installation guide for a specific tool
  static Future<void> openInstallationGuide(String toolName) async {
    final url = getInstallationUrl(toolName);
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  /// Generate install button text for a tool
  static String getInstallButtonText(String toolName) {
    return 'Install ${getDisplayName(toolName)}';
  }

  /// Check if error indicates a missing CLI tool
  static bool isCliToolError(String errorMessage) {
    return detectMissingTool(errorMessage) != null;
  }

  /// Check if any error in a list indicates a missing CLI tool
  static bool hasCliToolError(List<String> errors) {
    return detectMissingToolFromErrors(errors) != null;
  }
}
