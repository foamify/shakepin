import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/cli_tool_helper.dart';
import 'package:shakepin/services/settings_service.dart';
import 'package:shakepin/state.dart';

/// Service to track the availability of CLI tools and notify UI components
class CliToolAvailabilityService extends ChangeNotifier {
  static final CliToolAvailabilityService _instance = CliToolAvailabilityService._internal();
  factory CliToolAvailabilityService() => _instance;
  CliToolAvailabilityService._internal();

  final Map<String, bool> _toolAvailability = {};
  final Map<String, String?> _toolPathCache = {}; // Cache tool paths to avoid repeated settings calls
  Timer? _checkTimer;
  Timer? _debounceTimer;
  bool _isInitialized = false;
  StreamSubscription? _settingsSubscription;
  VoidCallback? _appModeCallback;
  bool _isChecking = false; // Prevent overlapping checks

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
    
    print('[CLI_AVAIL] Initializing service...');
    // Pre-load tool paths cache in parallel before checking
    await _refreshToolPaths();
    print('[CLI_AVAIL] Tool paths cached: $_toolPathCache');
    await _checkAllTools();
    print('[CLI_AVAIL] Initial tool availability: $_toolAvailability');
    _isInitialized = true;
    
    // Listen to settings changes to refresh tool availability
    _settingsSubscription = SettingsService.settingsStream.listen((settings) {
      print('[CLI_AVAIL] Settings changed: $settings');
      // Refresh ALL tools on ANY setting change
      print('[CLI_AVAIL] Setting changed, scheduling refresh...');
      // A setting was updated, debounce rapid changes and refresh availability
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        print('[CLI_AVAIL] Debounce timer fired, refreshing...');
        _refreshToolPaths();
        _checkAllTools();
      });
    });
    
    // Listen to app mode changes to refresh tool availability
    _appModeCallback = () {
      print('[CLI_AVAIL] App mode changed to: ${appMode.value}');
      // Debounce mode changes to avoid excessive checks
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        print('[CLI_AVAIL] App mode change debounce fired, refreshing...');
        _checkAllTools();
      });
    };
    appMode.addListener(_appModeCallback!);
    
    // Start periodic checks every 30 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAllTools();
    });
  }

  /// Force refresh tool availability
  Future<void> refresh() async {
    await _refreshToolPaths();
    await _checkAllTools();
  }

  /// Refresh tool paths cache from settings (non-blocking)
  Future<void> _refreshToolPaths() async {
    print('[CLI_AVAIL] Refreshing tool paths cache...');
    final paths = await Future.wait([
      SettingsService.getSetting<String>('ffmpegPath'),
      SettingsService.getSetting<String>('galleryDlPath'),
      SettingsService.getSetting<String>('gifskiPath'),
      SettingsService.getSetting<String>('ytDlpPath'),
      SettingsService.getSetting<String>('imagemagickPath'),
      SettingsService.getSetting<String>('sevenZipPath'),
    ]);

    _toolPathCache['ffmpeg'] = paths[0];
    _toolPathCache['gallery-dl'] = paths[1];
    _toolPathCache['gifski'] = paths[2];
    _toolPathCache['yt-dlp'] = paths[3];
    _toolPathCache['imagemagick'] = paths[4];
    _toolPathCache['7z'] = paths[5];
    print('[CLI_AVAIL] Tool paths refreshed: $_toolPathCache');
  }

  /// Check availability of all known CLI tools in parallel (non-blocking)
  Future<void> _checkAllTools() async {
    // Prevent overlapping checks
    if (_isChecking) {
      print('[CLI_AVAIL] Already checking, skipping...');
      return;
    }
    _isChecking = true;

    try {
      final toolsToCheck = [
        'ffmpeg',
        'ffprobe', 
        'imagemagick',
        'yt-dlp',
        'gallery-dl',
        'gifski',
        '7z',
      ];

      print('[CLI_AVAIL] Checking ${toolsToCheck.length} tools in parallel...');

      // Check all tools in parallel for speed
      // Use eagerError: false so one failure doesn't stop all checks
      final results = await Future.wait(
        toolsToCheck.map((tool) => _checkToolAvailability(tool)),
        eagerError: false,
      );

      print('[CLI_AVAIL] Check results: $results');

      // Update availability and track changes
      bool hasChanges = false;
      for (int i = 0; i < toolsToCheck.length; i++) {
        final tool = toolsToCheck[i];
        final wasAvailable = _toolAvailability[tool] ?? false;
        final isAvailable = results[i];
        
        if (wasAvailable != isAvailable) {
          _toolAvailability[tool] = isAvailable;
          hasChanges = true;
        }
      }

      if (hasChanges) {
        print('[CLI_AVAIL] Availability changed, notifying listeners');
        notifyListeners();
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Check availability of a specific tool by checking stored path or system PATH
  Future<bool> _checkToolAvailability(String toolName) async {
    try {
      // Always fetch from settings first (don't use cache) to ensure we have the latest
      String? storedPath;
      switch (toolName) {
        case 'ffmpeg':
          storedPath = await SettingsService.getSetting<String>('ffmpegPath');
          break;
        case 'gallery-dl':
          storedPath = await SettingsService.getSetting<String>('galleryDlPath');
          break;
        case 'gifski':
          storedPath = await SettingsService.getSetting<String>('gifskiPath');
          break;
        case 'yt-dlp':
          storedPath = await SettingsService.getSetting<String>('ytDlpPath');
          break;
        case 'imagemagick':
          storedPath = await SettingsService.getSetting<String>('imagemagickPath');
          break;
        case '7z':
          storedPath = await SettingsService.getSetting<String>('sevenZipPath');
          break;
        case 'ffprobe':
          // ffprobe has no custom path setting, always use system PATH
          storedPath = null;
          break;
        default:
          storedPath = null;
      }
      
      // If we have a stored path, check if the file exists
      if (storedPath != null && storedPath.isNotEmpty) {
        print('[CLI_AVAIL] Checking $toolName at custom path: $storedPath');
        final file = File(storedPath);
        final exists = await file.exists();
        if (exists) {
          print('[CLI_AVAIL] $toolName found at custom path');
          return true;
        }
        print('[CLI_AVAIL] $toolName not found at custom path, checking system PATH...');
      } else {
        print('[CLI_AVAIL] No custom path for $toolName, checking system PATH...');
      }
      
      // Fallback to system PATH check for tools without stored paths
      // or when stored path doesn't exist
      switch (toolName) {
        case 'ffmpeg':
          final available = await cli.isFFmpegAvailable();
          print('[CLI_AVAIL] ffmpeg available on system PATH: $available');
          return available;
        case 'ffprobe':
          final available = await cli.isFFprobeAvailable();
          print('[CLI_AVAIL] ffprobe available on system PATH: $available');
          return available;
        case 'imagemagick':
          // ImageMagick binary is 'magick'
          final result = await cli.run('which', ['magick'], noThrow: true);
          print('[CLI_AVAIL] imagemagick available on system PATH: ${result.exitCode == 0}');
          return result.exitCode == 0;
        case 'yt-dlp':
        case 'gallery-dl':
        case 'gifski':
          // Use generic 'which' command for system PATH check
          final result = await cli.run('which', [toolName], noThrow: true);
          print('[CLI_AVAIL] $toolName available on system PATH: ${result.exitCode == 0}');
          return result.exitCode == 0;
        case '7z':
          // 7-Zip binary is '7zz' on macOS
          final result7z = await cli.run('which', ['7zz'], noThrow: true);
          if (result7z.exitCode == 0) {
            print('[CLI_AVAIL] 7z available on system PATH (7zz): true');
            return true;
          }
          // Also try '7z' for compatibility
          final resultAlt = await cli.run('which', ['7z'], noThrow: true);
          print('[CLI_AVAIL] 7z available on system PATH (7z): ${resultAlt.exitCode == 0}');
          return resultAlt.exitCode == 0;
        default:
          print('[CLI_AVAIL] Unknown tool $toolName, returning false');
          return false;
      }
    } catch (e) {
      print('[CLI_AVAIL] Error checking $toolName: $e');
      // Return false on any error instead of propagating
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
    _debounceTimer?.cancel();
    _settingsSubscription?.cancel();
    if (_appModeCallback != null) {
      appMode.removeListener(_appModeCallback!);
    }
    super.dispose();
  }
}

/// Global instance for easy access
final cliToolAvailability = CliToolAvailabilityService();