import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

// Top-level final variable for easy access
final logger = Logger._();

class Logger {
  late File _logFile;
  bool _initialized = false;
  static const maxLogSizeBytes = 5 * 1024 * 1024; // 5MB limit
  static const maxLogRetentionDays = 7;
  late String _appName;
  late String _appVersion;
  late Directory _logsDirectory;

  // Private constructor
  Logger._() {
    // Initialize synchronously to prevent race conditions
    _init().then((_) => _initialized = true);
  }

  Future<void> _init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appName = packageInfo.appName;
      _appVersion = packageInfo.version;

      final directory = await getApplicationDocumentsDirectory();
      _logsDirectory =
          Directory('${directory.path}${Platform.pathSeparator}logs');
      if (!await _logsDirectory.exists()) {
        await _logsDirectory.create(recursive: true);
      }
      print('Logs directory: ${_logsDirectory.path}');

      await _cleanOldLogs();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedPath =
          '${_logsDirectory.path}${Platform.pathSeparator}${_appName}_$timestamp.log';
      _logFile = File(sanitizedPath);

      if (!await _logFile.exists()) {
        await _logFile.create(recursive: true);
        await _writeHeader();
      }

      await _rotateLogsIfNeeded();
      _initialized = true; // Only set after all initialization is complete
    } catch (e) {
      _logError('Failed to initialize logger', e);
      rethrow; // Let the caller know initialization failed
    }
  }

  Future<void> _cleanOldLogs() async {
    try {
      final files = await _logsDirectory.list().toList();
      final now = DateTime.now();

      for (var entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age.inDays >= maxLogRetentionDays) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      _logError('Failed to clean old logs', e);
    }
  }

  Future<bool> _checkStorageSpace() async {
    try {
      final stat = await _logsDirectory.stat();
      // Ensure at least 100MB free space
      return stat.size < await _getAvailableSpace() - (100 * 1024 * 1024);
    } catch (e) {
      _logError('Failed to check storage space', e);
      return false;
    }
  }

  Future<int> _getAvailableSpace() async {
    try {
      final result = await Process.run('df', ['-k', _logsDirectory.path]);
      final lines = result.stdout.toString().split('\n');
      if (lines.length >= 2) {
        final values = lines[1].split(RegExp(r'\s+'));
        return int.parse(values[3]) * 1024; // Convert KB to bytes
      }
    } catch (e) {
      _logError('Failed to get available space', e);
    }
    return 0;
  }

  Future<void> _writeHeader() async {
    final header = '''
===========================================
Application Log: $_appName
Version: $_appVersion
Device: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
Started: ${_formatDateTime(DateTime.now())}
===========================================

''';
    await _logFile.writeAsString(header);
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _getCallerLocation() {
    try {
      final frames = StackTrace.current.toString().split('\n');
      // Skip first 2 frames (current method and log method)
      final callerFrame = frames.length > 2 ? frames[2] : '';
      final regex = RegExp(r'#\d+\s+(.*) \(.*\)');
      final match = regex.firstMatch(callerFrame);
      return match?.group(1) ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> log(String message, {LogLevel level = LogLevel.info}) async {
    debugPrint(message);
    if (!_initialized) {
      await _init();
    }

    if (!await _checkStorageSpace()) {
      _logError('Insufficient storage space', 'Unable to write logs');
      return;
    }

    try {
      final timestamp = _formatDateTime(DateTime.now());
      final caller = _getCallerLocation();
      final logEntry =
          '$timestamp | ${level.name.toUpperCase().padRight(7)} | $caller | $message\n';
      await _logFile.writeAsString(logEntry, mode: FileMode.append);
      await _rotateLogsIfNeeded();
    } catch (e) {
      _logError('Failed to write log', e);
    }
  }

  Future<void> _rotateLogsIfNeeded() async {
    try {
      final stats = await _logFile.stat();
      if (stats.size > maxLogSizeBytes) {
        final backupFile = File('${_logFile.path}.bak');
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
        await _logFile.copy('${_logFile.path}.bak');
        await _logFile.writeAsString('');
      }
    } catch (e) {
      _logError('Failed to rotate logs', e);
    }
  }

  void _logError(String message, dynamic error) {
    // Use print only as last resort for logger errors
    final timestamp = DateTime.now().toIso8601String();
    logger.log('$timestamp [ERROR] $message: $error');
  }

  Future<void> clearLogs() async {
    if (!_initialized) return;

    try {
      await _logFile.writeAsString('');
    } catch (e) {
      _logError('Failed to clear logs', e);
    }
  }

  Future<String?> getLogs() async {
    if (!_initialized) return null;

    try {
      return await _logFile.readAsString();
    } catch (e) {
      _logError('Failed to read logs', e);
      return null;
    }
  }
}
