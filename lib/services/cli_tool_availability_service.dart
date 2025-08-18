import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/cli_tool_helper.dart';

/// Service to track the availability of CLI tools and notify UI components
class CliToolAvailabilityService extends ChangeNotifier {
  static final CliToolAvailabilityService _instance = CliToolAvailabilityService._internal();
  factory CliToolAvailabilityService() => _instance;
  CliToolAvailabilityService._internal();

  final Map<String, bool> _toolAvailability = {};
  Timer? _checkTimer;
  bool _isInitialized = false;

  /// Get availability status for a specific tool
  bool isToolAvailable(String toolName) {
    return _toolAvailability[toolName] ?? false;
  }

  /// Get availability status for multiple tools
  Map<String, bool> getToolsAvailability(List<String> toolNames) {
    return Map.fromEntries(
      toolNames.map((tool) => MapEntry(tool, isToolAvailable(tool)))
    );
  }

  /// Check if any of the required tools are missing
  bool hasAnyMissingTools(List<String> requiredTools) {
    return requiredTools.any((tool) => !isToolAvailable(tool));
  }

  /// Get list of missing tools from a required list
  List<String> getMissingTools(List<String> requiredTools) {
    return requiredTools.where((tool) => !isToolAvailable(tool)).toList();
  }

  /// Initialize the service and start periodic checks
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _checkAllTools();
    _isInitialized = true;
    
    // Start periodic checks every 30 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAllTools();
    });
  }

  /// Force refresh tool availability
  Future<void> refresh() async {
    await _checkAllTools();
  }

  /// Check availability of all known CLI tools
  Future<void> _checkAllTools() async {
    final toolsToCheck = [
      'ffmpeg',
      'ffprobe', 
      'imagemagick',
      'yt-dlp',
      'gallery-dl',
      'gifski',
      '7z',
    ];

    bool hasChanges = false;
    
    for (final tool in toolsToCheck) {
      final wasAvailable = _toolAvailability[tool] ?? false;
      final isAvailable = await _checkToolAvailability(tool);
      
      if (wasAvailable != isAvailable) {
        _toolAvailability[tool] = isAvailable;
        hasChanges = true;
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  /// Check availability of a specific tool by checking stored path or system PATH
  Future<bool> _checkToolAvailability(String toolName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get stored path for the tool
      String? storedPath;
      switch (toolName) {
        case 'ffmpeg':
          storedPath = prefs.getString('ffmpegPath');
          break;
        case 'gallery-dl':
          storedPath = prefs.getString('galleryDlPath');
          break;
        case 'gifski':
          storedPath = prefs.getString('gifskiPath');
          break;
        case 'yt-dlp':
          storedPath = prefs.getString('ytDlpPath');
          break;
        case 'imagemagick':
          storedPath = prefs.getString('imagemagickPath');
          break;
        case '7z':
          storedPath = prefs.getString('sevenZipPath');
          break;
        default:
          storedPath = null;
      }
      
      // If we have a stored path, check if the file exists
      if (storedPath != null && storedPath.isNotEmpty) {
        final file = File(storedPath);
        return await file.exists();
      }
      
      // Fallback to system PATH check for tools without stored paths
      // or when stored path is empty (using system default)
      switch (toolName) {
        case 'ffmpeg':
          return await cli.isFFmpegAvailable();
        case 'ffprobe':
          return await cli.isFFprobeAvailable();
        case 'imagemagick':
        case 'yt-dlp':
        case 'gallery-dl':
        case 'gifski':
        case '7z':
          // Use generic 'which' command for system PATH check
          final result = await cli.run('which', [toolName], noThrow: true);
          return result.exitCode == 0;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Get display name for a tool
  String getToolDisplayName(String toolName) {
    return CliToolHelper.getDisplayName(toolName);
  }

  /// Get installation URL for a tool
  String? getInstallationUrl(String toolName) {
    return CliToolHelper.getInstallationUrl(toolName);
  }

  /// Get install button text for a tool
  String getInstallButtonText(String toolName) {
    return CliToolHelper.getInstallButtonText(toolName);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

/// Global instance for easy access
final cliToolAvailability = CliToolAvailabilityService();