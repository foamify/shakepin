import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

final carriageReturn = Platform.isWindows ? '\r\n' : '\n';

String get shell {
  if (Platform.isMacOS || Platform.isLinux) {
    return Platform.environment['SHELL'] ?? 'bash';
  }

  if (Platform.isWindows) {
    return 'cmd.exe';
  }

  return 'sh';
}

final cli = Cli._();

class Cli {
  late final Pty pty;
  final listeners = <CliListener>[];
  Process? _currentProcess;

  Cli._() {
    init();
  }

  void _writeToPty(String text) {
    pty.write(const Utf8Encoder().convert('$text$carriageReturn'));
  }

  void init() {
    pty = Pty.start(shell);

    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen((text) {
      for (final listener in listeners) {
        listener.onOutput(text);
      }
    });

    pty.exitCode.then((code) {
      for (final listener in listeners) {
        listener.onExit('the process exited with exit code $code');
      }
    });
  }

  void dispose() {
    pty.kill();
  }

  void addListener(CliListener listener) {
    listeners.add(listener);
  }

  void removeListener(CliListener listener) {
    listeners.remove(listener);
  }

  void cancel() {
    if (_currentProcess != null) {
      _currentProcess!.kill();
      debugPrint('Process canceled');
    }
  }

  // MARK: - Process

  // MARK: - Convert to WAV

  Future<void> convertToWav(String inputPath, String outputPath,
      {Duration? startTime, Duration? endTime}) async {
    if (_currentProcess != null) {
      debugPrint('A process is already running. Please cancel it first.');
      return;
    }
    List<String> ffmpegArgs = ['-i', inputPath];

    if (startTime != null) {
      ffmpegArgs.addAll(['-ss', _formatDuration(startTime)]);
    }
    if (endTime != null) {
      ffmpegArgs.addAll(['-to', _formatDuration(endTime)]);
    }

    ffmpegArgs.addAll([
      '-acodec',
      'pcm_s16le',
      '-ar',
      '16000',
      '-ac',
      '1',
      '-y',
      outputPath,
    ]);

    try {
      _currentProcess = await Process.start('ffmpeg', ffmpegArgs);

      // Handle stdout
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.convertToWav] Output: $data');
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.convertToWav] Error: $data');
      });

      // Wait for the process to complete
      final exitCode = await _currentProcess!.exitCode;
      debugPrint('[Process.convertToWav] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('FFmpeg process failed with exit code: $exitCode');
      }
    } catch (e) {
      debugPrint('[Process.convertToWav] Error: $e');
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  // MARK: - Convert to ICO

  Future<void> convertToIco(String inputPath, String outputPath) async {
    if (_currentProcess != null) {
      debugPrint('A process is already running. Please cancel it first.');
      return;
    }
    final args = [
      'magick',
      inputPath,
      '-define',
      'icon:auto-resize=16,32,48,64,128,256,512',
      outputPath
    ];

    try {
      _currentProcess = await Process.start('magick', args);

      // Handle stdout
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.convertToIco] Output: $data');
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.convertToIco] Error: $data');
      });

      // Wait for the process to complete
      final exitCode = await _currentProcess!.exitCode;
      debugPrint('[Process.convertToIco] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('ImageMagick process failed with exit code: $exitCode');
      }
    } catch (e) {
      debugPrint('[Process.convertToIco] Error: $e');
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  // MARK: - Minify Image

  Future<void> minifyImage(String inputPath, String outputPath,
      {int quality = 95, void Function(double)? onProgress}) async {
    if (_currentProcess != null) {
      debugPrint('A process is already running. Please cancel it first.');
      return;
    }
    final outputPath = _getUniqueFilePath(inputPath, suffix: '_minified');
    final args = [
      inputPath,
      '-quality',
      quality.toString(),
      '-monitor',
      outputPath
    ];

    try {
      _currentProcess = await Process.start('magick', args);

      // Handle stdout
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.minifyImage] Output: $data');
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        // debugPrint('[Process.minifyImage] Error: $data');

        // Parse progress
        if (onProgress != null) {
          final match =
              RegExp(r'(\d+) of (\d+), (\d+)% complete').firstMatch(data);
          if (match != null) {
            final current = int.parse(match.group(1)!);
            final total = int.parse(match.group(2)!);
            final progress = current / total;
            onProgress(progress);
          }
        }
      });

      // Wait for the process to complete
      final exitCode = await _currentProcess!.exitCode;
      debugPrint('[Process.minifyImage] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('ImageMagick process failed with exit code: $exitCode');
      }
    } catch (e) {
      debugPrint('[Process.minifyImage] Error: $e');
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  // MARK: - Minify Video

  Future<void> minifyVideo(String inputPath, String outputPath,
      {String? format,
      String quality = 'medium',
      bool enableHardwareAcceleration = true,
      void Function(double)? onProgress}) async {
    if (_currentProcess != null) {
      debugPrint('A process is already running. Please cancel it first.');
      return;
    }

    format ??= path.extension(inputPath);

    final finalOutputPath =
        _getUniqueFilePath(outputPath, inputExtension: format);

    List<String> ffmpegArgs = [];

    if (enableHardwareAcceleration) {
      ffmpegArgs.addAll(['-hwaccel', 'auto']);
    }

    ffmpegArgs.add('-i');
    ffmpegArgs.add(inputPath);

    // Add format-specific encoding parameters
    switch (format) {
      case 'webm':
        final crf = switch (quality) {
          'lowest' => '51',
          'low' => '40',
          'medium' => '30',
          'high' => '23',
          'highest' => '12',
          _ => '30',
        };
        ffmpegArgs.addAll([
          '-c:v',
          'libvpx-vp9',
          '-crf',
          crf,
          '-b:v',
          '0',
          '-deadline',
          'good',
          '-cpu-used',
          '2',
          '-c:a',
          'libopus',
        ]);
      case 'gif':
        ffmpegArgs.addAll([
          '-vf',
          'fps=10,scale=500:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse',
          '-loop',
          '0',
        ]);
      default: // mp4
        final crf = switch (quality) {
          'lowest' => '51',
          'low' => '40',
          'medium' => '30',
          'high' => '23',
          'highest' => '12',
          _ => '30',
        };
        ffmpegArgs.addAll([
          '-c:v',
          'libx264',
          '-preset',
          'fast',
          '-crf',
          crf,
          '-pix_fmt',
          'yuv420p',
          '-profile:v',
          'high',
          '-level',
          '4.1',
          '-movflags',
          '+faststart',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
        ]);
    }

    ffmpegArgs.add(finalOutputPath);

    try {
      // Get video duration first
      final probeResult = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        inputPath
      ]);
      final duration = double.parse((probeResult.stdout as String).trim());

      _currentProcess = await Process.start('ffmpeg', ffmpegArgs);

      // Handle stdout
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.minifyVideo] Output: $data');
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.minifyVideo] Error: $data');

        // Parse progress
        final match =
            RegExp(r'time=(\d{2}):(\d{2}):(\d{2}\.\d{2})').firstMatch(data);
        if (match != null && onProgress != null) {
          final hours = int.parse(match.group(1)!);
          final minutes = int.parse(match.group(2)!);
          final seconds = double.parse(match.group(3)!);
          final currentTime = hours * 3600 + minutes * 60 + seconds;
          final progress = currentTime / duration;
          onProgress(progress);
        }
      });

      // Wait for the process to complete
      final exitCode = await _currentProcess!.exitCode;
      debugPrint('[Process.minifyVideo] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('FFmpeg process failed with exit code: $exitCode');
      }
    } catch (e) {
      debugPrint('[Process.minifyVideo] Error: $e');
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  String _getUniqueFilePath(String filePath,
      {String? suffix, String? inputExtension}) {
    if (!File(filePath).existsSync()) {
      return filePath;
    }

    final bool hasExtension = filePath.contains('.');
    final String fileExtension = inputExtension ??
        (hasExtension ? filePath.substring(filePath.lastIndexOf('.')) : '');
    final String pathWithoutExt = hasExtension
        ? filePath.substring(0, filePath.lastIndexOf('.'))
        : filePath;

    int counter = 0;
    String newPath;
    do {
      newPath =
          '$pathWithoutExt${suffix ?? ''}${counter > 0 ? ' ($counter)' : ''}$fileExtension';
      counter++;
    } while (File(newPath).existsSync());

    return newPath;
  }

  // MARK: - Utils

  String _formatDuration(Duration duration) {
    return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}';
  }

  Future<Duration?> getMediaDuration(String filePath) async {
    final args = [
      '-v',
      'quiet',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      filePath,
    ];

    try {
      final process = await Process.run('ffprobe', args);
      print('Executing "ffprobe ${args.join(' ')}"');

      final completer = Completer<Duration?>();
      String output = '';

      // Handle stdout
      process.stdout.transform(utf8.decoder).listen((data) {
        output += data;
      }, onDone: () {
        try {
          final duration = double.tryParse(output.trim());
          if (duration != null) {
            final durationMs =
                Duration(milliseconds: (duration * 1000).round());
            completer.complete(durationMs);
          } else {
            completer.complete(null);
          }
        } catch (e) {
          debugPrint('[Process.getMediaDuration] Error parsing duration: $e');
          completer.complete(null);
        }
      });

      // Handle stderr
      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.getMediaDuration] Error: $data');
      });

      // Wait for the process to complete
      final exitCode = await process.exitCode;
      debugPrint(
          '[Process.getMediaDuration] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('FFprobe process failed with exit code: $exitCode');
      }

      return await completer.future;
    } catch (e) {
      debugPrint('[Process.getMediaDuration] Error: $e');
      return null;
    }
  }

  Future<void> openFileLocation(String filePath) async {
    try {
      final process = await Process.start('open', ['-R', filePath]);

      // Handle stdout
      process.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.openFileLocation] Output: $data');
      });

      // Handle stderr
      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Process.openFileLocation] Error: $data');
      });

      // Wait for the process to complete
      final exitCode = await process.exitCode;
      debugPrint(
          '[Process.openFileLocation] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('Open command failed with exit code: $exitCode');
      }
    } catch (e) {
      debugPrint('[Process.openFileLocation] Error: $e');
      rethrow;
    }
  }

  // MARK: - Setup

  Future<void> setup({
    required Function(String step, double progress) onProgress,
    required Function(String error) onError,
    required Function() onSuccess,
  }) async {
    debugPrint('[Cli.setup] Starting setup...');

    final completer = Completer<void>();
    String currentStep = '';
    double progress = 0.0;

    void updateProgress(String text) {
      // Remove ANSI escape codes and extra whitespace
      text = text.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '').trim();

      if (text.isEmpty) return;

      debugPrint('[Cli.setup] Output: $text');

      final steps = [
        'Starting setup...',
        'Installing Homebrew...',
        'Homebrew installed',
        'Installing FFmpeg...',
        'FFmpeg installed',
        'Installing ImageMagick...',
        'ImageMagick installed',
        'Setup completed',
      ];

      final stepMessages = [
        'v1',
        'Homebrew is not installed',
        'Homebrew installation completed',
        'Installing ffmpeg',
        'ffmpeg installation completed',
        'Installing ImageMagick',
        'ImageMagick installation completed',
        'All checks and installations are completed successfully',
      ];

      for (int i = 0; i < steps.length; i++) {
        if (text.contains(stepMessages[i])) {
          progress = (i + 1) / steps.length;
          currentStep = steps[i];
          onProgress(currentStep, progress);
          break;
        }
      }

      if (text.contains('Error: An error occurred')) {
        currentStep = 'Error: Installation failed';
        progress = 0;
        onError(currentStep);
        completer.completeError(Exception('Setup failed'));
      }

      if (text.contains('All checks and installations are completed')) {
        onSuccess();
        completer.complete();
      }
    }

    final setupListener = LocalCliListener()
      ..onOutputCallback = updateProgress
      ..onExitCallback = (text) {
        debugPrint('[Cli.setup] Process exited: $text');
        completer.complete();
      };

    addListener(setupListener);

    final setupScript = await rootBundle.loadString('assets/setup.sh');
    final temporaryFile = await getTemporaryDirectory();
    final scriptPath = '${temporaryFile.path}/setup.sh';
    await File(scriptPath).writeAsString(setupScript);
    // Set execute permission for the script
    await Process.run('chmod', ['+x', scriptPath]);

    try {
      _writeToPty(scriptPath);
      await completer.future;
      debugPrint('[Cli.setup] Setup completed');
    } catch (e) {
      debugPrint('[Cli.setup] Setup error: $e');
      rethrow;
    } finally {
      removeListener(setupListener);
      File(scriptPath).delete();
    }
  }
}

mixin CliListener {
  void onOutput(String text);
  void onExit(String text);
}

class LocalCliListener implements CliListener {
  void Function(String)? onOutputCallback;
  void Function(String)? onExitCallback;
  bool _startedOutput = false;

  @override
  void onOutput(String text) {
    if (!_startedOutput) {
      if (text.contains('[?2004l')) {
        _startedOutput = true;
      }
      return;
    }

    if (onOutputCallback != null) {
      onOutputCallback!(text);
    }
  }

  @override
  void onExit(String text) {
    if (onExitCallback != null) {
      onExitCallback!(text);
    }
  }
}
