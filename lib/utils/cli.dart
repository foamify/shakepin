import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';

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
      logger.log('Process canceled');
    }
  }

  Future<ProcessResult> executeNativeProcess(
      String command, List<String> arguments) async {
    try {
      logger.log('[Native Process] Starting: $command ${arguments.join(' ')}');
      final result = await dropChannel.startProcess(command, arguments);
      logger
          .log('[Native Process] Completed with exit code: ${result.exitCode}');
      if (result.exitCode != 0) {
        logger.log('[Native Process] Error output: ${result.stderr}');
      }
      return result;
    } catch (e) {
      logger.log('[Native Process] Error: $e');
      rethrow;
    }
  }

  // MARK: - Process

  // MARK: - Convert to WAV

  Future<void> convertToWav(String inputPath,
      {Duration? startTime, Duration? endTime, void Function(double)? onProgress}) async {
    logger.log('=== Starting WAV Conversion Process ===');
    logger.log('Input path: $inputPath');
    
    if (startTime != null) logger.log('Start time: ${_formatDuration(startTime)}');
    if (endTime != null) logger.log('End time: ${_formatDuration(endTime)}');

    if (_currentProcess != null) {
      logger.log('⚠️ Process conflict: Another conversion process is running');
      logger.log('Current process PID: ${_currentProcess!.pid}');
      logger.log('Aborting new conversion request');
      return;
    }

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      logger.log('❌ Error: Input file does not exist at path: $inputPath');
      throw FileSystemException('Input file not found', inputPath);
    }

    final outputPath = _getUniqueFilePath(inputPath,
        suffix: '_converted', inputExtension: 'wav');
    logger.log('Generated output path: $outputPath');

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
      '-progress',
      'pipe:1',
      outputPath,
    ]);

    logger.log('FFmpeg command arguments: ${ffmpegArgs.join(" ")}');

    try {
      logger.log('🚀 Launching FFmpeg process...');
      _currentProcess = await Process.start('ffmpeg', ffmpegArgs);

      // Handle stdout
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        logger.log('[FFmpeg Output] $data');
        
        if (onProgress != null) {
          final timeMatch = RegExp(r'out_time=(\d{2}):(\d{2}):(\d{2}\.\d{2})').firstMatch(data);
          if (timeMatch != null) {
            final hours = int.parse(timeMatch.group(1)!);
            final minutes = int.parse(timeMatch.group(2)!);
            final seconds = double.parse(timeMatch.group(3)!);
            final currentTime = hours * 3600 + minutes * 60 + seconds;
            onProgress(currentTime / (endTime?.inSeconds ?? 100).toDouble());
            logger.log('Processing time: ${_formatDuration(Duration(seconds: currentTime.round()))}');
          }
        }
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        logger.log('[FFmpeg Error] $data');
      });

      // Wait for the process to complete
      final exitCode = await _currentProcess!.exitCode;
      logger.log('Process exited with code: $exitCode');

      if (exitCode != 0) {
        logger.log('❌ Process failed with exit code: $exitCode');
        throw Exception('FFmpeg process failed with exit code: $exitCode');
      }

      final outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        final outputFileSize = await outputFile.length();
        logger.log('Output file size: ${(outputFileSize / 1024).toStringAsFixed(2)} KB');
      } else {
        logger.log('❌ Warning: Output file was not created');
      }

    } catch (e) {
      logger.log('❌ Critical error during conversion: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      _currentProcess = null;
      logger.log('=== WAV Conversion Process Completed ===');
    }
  }

  // MARK: - Convert to ICO

  Future<void> convertToIco(String inputPath, String outputPath) async {
    if (_currentProcess != null) {
      logger.log('A process is already running. Please cancel it first.');
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
        logger.log('[Process.convertToIco] Output: $data');
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        logger.log('[Process.convertToIco] Error: $data');
      });

      // Wait for the process to complete
      final exitCode = await _currentProcess!.exitCode;
      logger.log('[Process.convertToIco] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('ImageMagick process failed with exit code: $exitCode');
      }
    } catch (e) {
      logger.log('[Process.convertToIco] Error: $e');
      rethrow;
    } finally {
      _currentProcess = null;
    }
  }

  // MARK: - Minify Image

  Future<void> minifyImage(String inputPath,
      {String? fileExtension,
      int quality = 95,
      required int downScale,
      void Function(double)? onProgress}) async {
    logger.log('=== Starting Image Minification Process ===');
    logger.log('Input path: $inputPath');
    logger.log('Target quality: $quality');
    logger.log('Target format: ${fileExtension ?? "same as input"}');

    if (_currentProcess != null) {
      logger
          .log('⚠️ Process conflict: Another minification process is running');
      logger.log('Current process PID: ${_currentProcess!.pid}');
      logger.log('Aborting new minification request');
      return;
    }

    final outputPath = _getUniqueFilePath(inputPath,
        suffix: '_minified', inputExtension: fileExtension);
    logger.log('Generated output path: $outputPath');

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      logger.log('❌ Error: Input file does not exist at path: $inputPath');
      throw FileSystemException('Input file not found', inputPath);
    }

    final inputFileSize = await inputFile.length();
    logger.log(
        'Input file size: ${(inputFileSize / 1024).toStringAsFixed(2)} KB');

    final args = [
      inputPath,
    ];
    
    // Add downscaling if needed
    if (downScale > 1) {
      args.addAll(['-resize', '${downScale}%']);
      logger.log('Applying downscale factor: $downScale (${downScale}% of original size)');
    }

    args.addAll([
      '-quality',
      quality.toString(),
      '-monitor',
      outputPath
    ]);
    
    logger.log('ImageMagick command arguments: $args');

    try {
      logger.log('🚀 Launching ImageMagick process...');

      callback(line) {
        if (onProgress != null) {
          final match =
              RegExp(r'(\d+) of (\d+), (\d+)% complete').firstMatch(line);
          if (match != null) {
            final current = int.parse(match.group(1)!);
            final total = int.parse(match.group(2)!);
            final progress = int.parse(match.group(3)!);
            logger.log(
                'Processing frame $current of $total (${(progress).toStringAsFixed(1)}%)');
            onProgress(progress / 100);
          }
        }
      }

      dropChannel.addCliErrorCallback(callback);

      final result = await executeNativeProcess(
          'magick', args.map((e) => "'$e'").toList());
      logger.log('Process completed with exit code: ${result.exitCode}');
      logger.log('Output: ${result.stdout}');
      logger.log('Error: ${result.stderr}');
      logger.log('Process completed with exit code: ${result.exitCode}');

      dropChannel.removeCliErrorCallback(callback);

      // Parse progress from stderr

      final exitCode = result.exitCode;
      logger.log('Process exited with code: $exitCode');

      if (exitCode != 0) {
        logger.log('❌ Process failed with exit code: $exitCode');
        throw Exception('ImageMagick process failed with exit code: $exitCode');
      }

      final outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        final outputFileSize = await outputFile.length();
        final compressionRatio = (1 - (outputFileSize / inputFileSize)) * 100;
        logger.log(
            'Output file size: ${(outputFileSize / 1024).toStringAsFixed(2)} KB');
        logger
            .log('Compression ratio: ${compressionRatio.toStringAsFixed(2)}%');
      } else {
        logger.log('❌ Warning: Output file was not created');
      }
    } catch (e) {
      logger.log('❌ Critical error during minification: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      _currentProcess = null;
      logger.log('=== Image Minification Process Completed ===');
    }
  }

  // MARK: - Minify Video

  Future<void> minifyVideo(String inputPath,
      {String? format,
      String quality = 'medium',
      bool enableHardwareAcceleration = true,
      void Function(double)? onProgress}) async {
    await logger.log('[Process.minifyVideo] Starting video minification');
    if (_currentProcess != null) {
      await logger.log('A process is already running. Please cancel it first.');
      return;
    }

    format ??= path.extension(inputPath);
    await logger.log('[Process.minifyVideo] Input path: $inputPath');
    await logger.log('[Process.minifyVideo] Format: $format');
    await logger.log('[Process.minifyVideo] Quality: $quality');
    await logger.log(
        '[Process.minifyVideo] Hardware acceleration: $enableHardwareAcceleration');

    final finalOutputPath =
        _getUniqueFilePath(inputPath, inputExtension: format);
    await logger.log('[Process.minifyVideo] Output path: $finalOutputPath');

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
        await logger
            .log('[Process.minifyVideo] Using WebM encoding with CRF: $crf');
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
        await logger.log('[Process.minifyVideo] Using GIF encoding');
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
        await logger
            .log('[Process.minifyVideo] Using MP4 encoding with CRF: $crf');
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
    await logger.log(
        '[Process.minifyVideo] FFmpeg command: ffmpeg ${ffmpegArgs.join(" ")}');

    try {
      await logger.log('[Process.minifyVideo] Getting video duration...');
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
      await logger.log(
          '[Process.minifyVideo] Video duration: ${duration.toStringAsFixed(2)} seconds');

      await logger.log('[Process.minifyVideo] Starting FFmpeg process...');
      _currentProcess = await Process.start('ffmpeg', ffmpegArgs);

      // Handle stdout
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) async {
        await logger.log('[Process.minifyVideo] Output: $data');
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) async {
        await logger.log('[Process.minifyVideo] FFmpeg: $data');

        // Parse progress
        final match =
            RegExp(r'time=(\d{2}):(\d{2}):(\d{2}\.\d{2})').firstMatch(data);
        if (match != null && onProgress != null) {
          final hours = int.parse(match.group(1)!);
          final minutes = int.parse(match.group(2)!);
          final seconds = double.parse(match.group(3)!);
          final currentTime = hours * 3600 + minutes * 60 + seconds;
          final progress = currentTime / duration;
          await logger.log(
              '[Process.minifyVideo] Progress: ${(progress * 100).toStringAsFixed(2)}%');
          onProgress(progress);
        }
      });

      // Wait for the process to complete
      final exitCode = await _currentProcess!.exitCode;
      await logger.log(
          '[Process.minifyVideo] Process completed with exit code: $exitCode');

      if (exitCode != 0) {
        throw Exception('FFmpeg process failed with exit code: $exitCode');
      }

      final inputSize = await File(inputPath).length();
      final outputSize = await File(finalOutputPath).length();
      final compressionRatio = (1 - (outputSize / inputSize)) * 100;

      await logger.log('[Process.minifyVideo] Compression results:');
      await logger.log(
          '[Process.minifyVideo] Original size: ${(inputSize / 1024 / 1024).toStringAsFixed(2)} MB');
      await logger.log(
          '[Process.minifyVideo] Compressed size: ${(outputSize / 1024 / 1024).toStringAsFixed(2)} MB');
      await logger.log(
          '[Process.minifyVideo] Compression ratio: ${compressionRatio.toStringAsFixed(2)}%');
    } catch (e) {
      await logger.log('[Process.minifyVideo] Error: $e');
      rethrow;
    } finally {
      _currentProcess = null;
      await logger.log('[Process.minifyVideo] Process cleanup completed');
    }
  }

  String _getUniqueFilePath(String filePath,
      {String? suffix, String? inputExtension}) {
    if (!File(filePath).existsSync()) {
      return filePath;
    }

    final bool hasExtension = filePath.contains('.');
    final String fileExtension = (inputExtension ??
            (hasExtension ? filePath.substring(filePath.lastIndexOf('.')) : ''))
        .toLowerCase();
    final String pathWithoutExt = hasExtension
        ? filePath.substring(0, filePath.lastIndexOf('.'))
        : filePath;

    int counter = 0;
    String newPath;
    do {
      final String extensionToUse = fileExtension.startsWith('.')
          ? fileExtension.substring(1)
          : fileExtension;
      newPath =
          '$pathWithoutExt${suffix ?? ''}${counter > 0 ? ' ($counter)' : ''}.${extensionToUse}';
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
      logger.log('Executing "ffprobe ${args.join(' ')}"');

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
          logger.log('[Process.getMediaDuration] Error parsing duration: $e');
          completer.complete(null);
        }
      });

      // Handle stderr
      process.stderr.transform(utf8.decoder).listen((data) {
        logger.log('[Process.getMediaDuration] Error: $data');
      });

      // Wait for the process to complete
      final exitCode = await process.exitCode;
      logger.log(
          '[Process.getMediaDuration] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('FFprobe process failed with exit code: $exitCode');
      }

      return await completer.future;
    } catch (e) {
      logger.log('[Process.getMediaDuration] Error: $e');
      return null;
    }
  }

  Future<void> openFileLocation(String filePath) async {
    try {
      final process = await Process.start('open', ['-R', filePath]);

      // Handle stdout
      process.stdout.transform(utf8.decoder).listen((data) {
        logger.log('[Process.openFileLocation] Output: $data');
      });

      // Handle stderr
      process.stderr.transform(utf8.decoder).listen((data) {
        logger.log('[Process.openFileLocation] Error: $data');
      });

      // Wait for the process to complete
      final exitCode = await process.exitCode;
      logger.log(
          '[Process.openFileLocation] Process exited with code: $exitCode');

      if (exitCode != 0) {
        throw Exception('Open command failed with exit code: $exitCode');
      }
    } catch (e) {
      logger.log('[Process.openFileLocation] Error: $e');
      rethrow;
    }
  }

  // MARK: - Setup

  Future<void> setup({
    required Function(String step, double progress) onProgress,
    required Function(String error) onError,
    required Function() onSuccess,
  }) async {
    logger.log('[Cli.setup] Starting setup...');

    final completer = Completer<void>();
    String currentStep = '';
    double progress = 0.0;

    void updateProgress(String text) {
      // Remove ANSI escape codes and extra whitespace
      text = text.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '').trim();

      if (text.isEmpty) return;

      logger.log('[Cli.setup] Output: $text');

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
        logger.log('[Cli.setup] Process exited: $text');
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
      logger.log('[Cli.setup] Setup completed');
    } catch (e) {
      logger.log('[Cli.setup] Setup error: $e');
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
