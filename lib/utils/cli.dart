import 'dart:async';
import 'dart:convert';
import 'dart:io' hide Process;

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
    dropChannel.cancelProcess();
    logger.log('Process canceled');
  }

  // Future<ProcessResult> executeNativeProcess(
  //     String command, List<String> arguments) async {
  //   try {
  //     logger.log('[Native Process] Starting: $command ${arguments.join(' ')}');
  //     final result = await executeNativeProcess(command, arguments);
  //     logger
  //         .log('[Native Process] Completed with exit code: ${result.exitCode}');
  //     if (result.exitCode != 0) {
  //       logger.log('[Native Process] Error output: ${result.stderr}');
  //     }
  //     return result;
  //   } catch (e) {
  //     logger.log('[Native Process] Error: $e');
  //     cancel();
  //     rethrow;
  //   }
  // }

  /// Executes a one-off native process with basic error handling and logging
  Future<ProcessResult> executeNativeProcess(
    String command,
    List<String> arguments,
  ) async {
    logger.log(
        '[Native Process] Starting: $command ${arguments.map((e) => "'$e'").join(' ')}');

    // Check if another process is running
    if (await dropChannel.isProcessRunning()) {
      const error = 'Another process is already running';
      logger.log('[Native Process] Error: $error');
      throw ProcessException(command, arguments, error, -1);
    }

    try {
      final result = await dropChannel.startProcess(
        command,
        arguments,
      );

      if (result.exitCode != 0) {
        final error =
            'Process failed with exit code: ${result.exitCode}\nError: ${result.stderr}';
        logger.log('[Native Process] $error');
        throw ProcessException(command, arguments, error, result.exitCode);
      }

      logger.log('[Native Process] Completed successfully');
      return result;
    } catch (e, stack) {
      logger.log('[Native Process] Error: $e');
      logger.log('[Native Process] Stack trace: $stack');
      dropChannel.cancelProcess();
      rethrow;
    }
  }

  // MARK: - Process

  // MARK: - Download Video using yt-dlp

  Future<void> downloadVideo(
    String urlString, {
    void Function(double)? onProgress,
  }) async {
    logger.log('=== Starting Media Download Process ===');
    logger.log('URL: $urlString');

    if (await dropChannel.isProcessRunning()) {
      logger.log('⚠️ Process conflict: Another download process is running');
      logger.log('Aborting new download request');
      return;
    }

    var outputDir = (await getDownloadsDirectory())?.path;

    if (outputDir == null) {
      logger.log(
          '❌ Error: Downloads directory not found. Using application documents directory');

      final documentsDir = await getApplicationDocumentsDirectory();
      outputDir = '${documentsDir.path}/Downloads';
      await Directory(outputDir).create(recursive: true);
    }

    // Create a template that limits the filename length
    // %(title).200B truncates title to 200 bytes if longer
    // %ext:3 limits extension to 3 characters
    final outputTemplate =
        path.join(outputDir, '%(uploader).30B - %(title).170B');

    final args = [
      '--no-mtime',
      '--progress',
      '--newline',
      '--restrict-filenames', // Replace special characters with _
      '--windows-filenames', // Ensure Windows compatibility
      '--trim-filenames', '200', // Limit filename length
      '-o',
      outputTemplate,
      urlString,
    ];

    try {
      logger.log('🚀 Launching yt-dlp process...');

      callback(String line) {
        if (onProgress != null) {
          // Match total fragments info
          if (line.contains('[hlsnative] Total fragments:')) {
            return;
          }

          // Match percentage pattern with fragment info
          final progressMatch =
              RegExp(r'\[download\]\s+(\d+\.?\d*)%.*\(frag\s+(\d+)\/(\d+)\)')
                  .firstMatch(line);
          if (progressMatch != null) {
            final percent = double.tryParse(progressMatch.group(1)!);
            final fragCurrent = int.tryParse(progressMatch.group(2)!);
            final fragTotal = int.tryParse(progressMatch.group(3)!);

            if (percent != null && fragCurrent != null && fragTotal != null) {
              // Calculate overall progress considering fragments
              final fragmentProgress = percent / 100;
              final overallProgress =
                  (fragCurrent - 1 + fragmentProgress) / fragTotal;

              onProgress(overallProgress);
              logger.log(
                  'Download progress: ${(overallProgress * 100).toStringAsFixed(1)}% (Fragment $fragCurrent/$fragTotal)');
            }
            return;
          }

          // Match for merging progress
          if (line.contains('[Merger]')) {
            onProgress(1.0);
            logger.log('Merging formats...');
            return;
          }

          // Match for 100% completion with different format
          if (line.contains('[download] 100% of')) {
            onProgress(1.0);
            logger.log('Download completed');
            return;
          }
        }
      }

      dropChannel.addCliOutputCallback(callback);

      final result = await executeNativeProcess('yt-dlp', args);

      dropChannel.removeCliOutputCallback(callback);

      if (result.exitCode != 0) {
        throw Exception(
            'yt-dlp process failed with exit code: ${result.exitCode}');
      }

      // Open the downloads folder
      await executeNativeProcess('open', [outputDir]);
    } catch (e) {
      logger.log('❌ Critical error during download: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      cancel();
      logger.log('=== Media Download Process Completed ===');
    }
  }

  Future<void> downloadImage(
    String urlString, {
    void Function(double)? onProgress,
  }) async {
    logger.log('=== Starting Image Download Process ===');
    logger.log('URL: $urlString');

    if (await dropChannel.isProcessRunning()) {
      logger.log('⚠️ Process conflict: Another download process is running');
      logger.log('Aborting new download request');
      return;
    }

    var outputDir = (await getDownloadsDirectory())?.path;

    if (outputDir == null) {
      logger.log(
          '❌ Error: Downloads directory not found. Using application documents directory');
      final documentsDir = await getApplicationDocumentsDirectory();
      outputDir = '${documentsDir.path}/Downloads';
      await Directory(outputDir).create(recursive: true);
    }

    final args = [
      '--directory',
      outputDir,
      '--filename',
      '{filename}.{extension}',
      '--verbose',
      urlString,
    ];

    try {
      logger.log('🚀 Launching gallery-dl process...');

      callback(String line) {
        if (onProgress != null) {
          // Match download progress patterns
          if (line.contains('Download complete')) {
            onProgress(1.0);
            logger.log('Download completed');
            return;
          }

          // Match percentage pattern
          final progressMatch = RegExp(r'(\d+)%').firstMatch(line);
          if (progressMatch != null) {
            final percent = double.tryParse(progressMatch.group(1)!);
            if (percent != null) {
              onProgress(percent / 100);
              logger.log('Download progress: $percent%');
            }
          }
        }
      }

      dropChannel.addCliOutputCallback(callback);

      final result = await executeNativeProcess('gallery-dl', args);

      dropChannel.removeCliOutputCallback(callback);

      if (result.exitCode != 0) {
        throw Exception(
            'gallery-dl process failed with exit code: ${result.exitCode}');
      }

      // Open the downloads folder
      await executeNativeProcess('open', [outputDir]);
    } catch (e) {
      logger.log('❌ Critical error during download: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      cancel();
      logger.log('=== Image Download Process Completed ===');
    }
  }

  // MARK: - Convert to WAV

  Future<void> convertToWav(String inputPath,
      {Duration? startTime,
      Duration? endTime,
      void Function(double)? onProgress}) async {
    logger.log('=== Starting WAV Conversion Process ===');
    logger.log('Input path: $inputPath');

    if (startTime != null) {
      logger.log('Start time: ${_formatDuration(startTime)}');
    }
    if (endTime != null) logger.log('End time: ${_formatDuration(endTime)}');

    if (await dropChannel.isProcessRunning()) {
      logger.log('⚠️ Process conflict: Another conversion process is running');
      logger.log('Aborting new conversion request');
      return;
    }

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      logger.log('❌ Error: Input file not found at path: $inputPath');
      throw FileSystemException('Input file not found', inputPath);
    }

    final outputPath = _getUniqueFilePath(inputPath,
        suffix: '_converted', inputExtension: 'wav');
    logger.log('Generated output path: $outputPath');

    Duration? duration = Duration.zero;

    try {
      duration = await getMediaDuration(inputPath);
      logger.log('Media duration: ${duration.toString()}');
    } catch (e) {
      logger.log('❌ Error getting media duration: $e');
      throw Exception('Failed to get media duration: $e');
    }
    if (duration == null) {
      throw Exception('Could not determine media duration');
    }
    final durationInSeconds = duration.inMilliseconds / 1000.0;
    logger.log('Media duration: ${durationInSeconds}s');

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

      callback(String line) {
        if (onProgress != null) {
          final timeMatch =
              RegExp(r'out_time=(\d+):(\d+):(\d+)\.(\d+)').firstMatch(line);
          if (timeMatch != null) {
            final hours = int.parse(timeMatch.group(1)!);
            final minutes = int.parse(timeMatch.group(2)!);
            final seconds = int.parse(timeMatch.group(3)!);
            final milliseconds = int.parse(timeMatch.group(4)!);

            final currentTime =
                hours * 3600 + minutes * 60 + seconds + milliseconds / 100;
            final progress = currentTime /
                durationInSeconds; // Fixed: using durationInSeconds instead of Duration

            onProgress(progress.clamp(0.0, 1.0));
            logger.log(
                'Conversion progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        }
      }

      dropChannel.addCliOutputCallback(callback);

      final result = await executeNativeProcess('ffmpeg', ffmpegArgs);

      dropChannel.removeCliOutputCallback(callback);

      if (result.exitCode != 0) {
        logger.log('❌ Process failed with exit code: ${result.exitCode}');
        throw Exception(
            'FFmpeg process failed with exit code: ${result.exitCode}');
      }

      if (onProgress != null) {
        onProgress(1.0);
      }

      final outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        final outputFileSize = await outputFile.length();
        logger.log(
            'Output file size: ${(outputFileSize / 1024).toStringAsFixed(2)} KB');
      } else {
        logger.log('❌ Warning: Output file was not created');
      }
    } catch (e) {
      logger.log('❌ Critical error during conversion: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      logger.log('=== WAV Conversion Process Completed ===');
    }
  }

  // MARK: - Convert to ICO

  Future<void> convertToIco(String inputPath) async {
    logger.log('=== Starting ICO Conversion Process ===');
    logger.log('Input path: $inputPath');

    if (await dropChannel.isProcessRunning()) {
      logger.log('⚠️ Process conflict: Another conversion process is running');
      logger.log('Aborting new conversion request');
      return;
    }

    final outputPath =
        _getUniqueFilePath(inputPath, suffix: '', inputExtension: 'ico');
    logger.log('Generated output path: $outputPath');

    final args = [
      inputPath,
      '-define',
      'icon:auto-resize=16,32,48,64,128,256,512',
      outputPath
    ];

    try {
      logger.log('🚀 Launching ImageMagick process...');
      logger.log('ImageMagick command arguments: ${args.join(" ")}');

      final result = await executeNativeProcess(
          'magick', args.map((e) => "'$e'").toList());
      logger.log('Process completed with exit code: ${result.exitCode}');
      logger.log('Output: ${result.stdout}');
      logger.log('Error: ${result.stderr}');

      if (result.exitCode != 0) {
        logger.log('❌ Process failed with exit code: ${result.exitCode}');
        throw Exception(
            'ImageMagick process failed with exit code: ${result.exitCode}');
      }
    } catch (e) {
      logger.log('❌ Critical error during ICO conversion: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      logger.log('=== ICO Conversion Process Completed ===');
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

    if (await dropChannel.isProcessRunning()) {
      logger
          .log('⚠️ Process conflict: Another minification process is running');
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
      args.addAll(['-resize', '$downScale%']);
      logger.log(
          'Applying downscale factor: $downScale ($downScale% of original size)');
    }

    args.addAll(['-quality', quality.toString(), '-monitor', outputPath]);

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
    if (await dropChannel.isProcessRunning()) {
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

    // Add progress monitoring flags
    ffmpegArgs.addAll([
      '-progress', 'pipe:2', // Output progress to stderr
      '-stats',
      '-i', inputPath,
    ]);

    // Add format-specific encoding parameters
    switch (format.toLowerCase()) {
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
          // Speed optimizations for VP9 (Not quite noticeable, so it's stilla TODO)
          '-deadline',
          'realtime', // Changed from 'good' to 'realtime' for faster encoding
          '-cpu-used',
          '4', // Increased from 2 to 4 for better speed
          '-row-mt', // Enable row-based multithreading
          '1',
          '-tile-columns', // Enable tiling
          '2',
          '-frame-parallel', // Enable frame parallel processing
          '1',
          '-threads', // Use all available CPU threads
          '0',
          '-c:a',
          'libopus',
          '-b:a', // Reduced audio bitrate
          '96k',
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
          '-c:v', 'libx264',
          '-preset', 'fast',
          '-crf', crf,
          '-pix_fmt', 'yuv420p',
          '-profile:v',
          'main', // Changed from 'high' to 'main' for better compatibility
          '-level', '4.0', // Changed from '4.1' to '4.0'
          '-tune', 'fastdecode', // Add tune option for faster decoding
          '-movflags', '+faststart',
          '-y', // Overwrite output file without asking
          '-c:a', 'aac',
          '-b:a', '128k',
          '-threads', '0', // Use optimal number of threads
        ]);
    }

    ffmpegArgs.add(finalOutputPath);
    await logger.log(
        '[Process.minifyVideo] FFmpeg command: ffmpeg ${ffmpegArgs.join(" ")}');

    try {
      await logger.log('[Process.minifyVideo] Getting video duration...');
      final duration = await getMediaDuration(inputPath);
      if (duration == null) {
        throw Exception('Could not determine video duration');
      }
      final durationInSeconds = duration.inMilliseconds / 1000.0;
      await logger.log('[Process.minifyVideo] Duration: ${durationInSeconds}s');

      await logger.log('[Process.minifyVideo] Starting FFmpeg process...');

      // Add progress tracking
      callback(String line) {
        if (onProgress != null) {
          // Improved progress parsing regex to handle more FFmpeg output formats
          final timeMatch =
              RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)|\btime=\s*(\d+\.\d+)')
                  .firstMatch(line);
          if (timeMatch != null) {
            double currentTime;
            if (timeMatch.group(1) != null) {
              // HH:MM:SS.ms format
              final hours = int.parse(timeMatch.group(1)!);
              final minutes = int.parse(timeMatch.group(2)!);
              final seconds = int.parse(timeMatch.group(3)!);
              final milliseconds = int.parse(timeMatch.group(4)!);
              currentTime =
                  hours * 3600 + minutes * 60 + seconds + milliseconds / 100;
            } else {
              // Seconds format
              currentTime = double.parse(timeMatch.group(5)!);
            }
            final progress = currentTime / durationInSeconds;
            onProgress(progress.clamp(0.0, 1.0));
            logger.log(
                '[Process.minifyVideo] Progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        }
      }

      dropChannel.addCliErrorCallback(callback);

      final result = await executeNativeProcess('ffmpeg', ffmpegArgs);
      logger.log('Process completed with exit code: ${result.exitCode}');

      dropChannel.removeCliErrorCallback(callback);

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
      await logger.log('[Process.minifyVideo] Process cleanup completed');
    }
  }

  Future<String?> archiveFiles(List<String> paths, String outputFolder,
      {void Function(double)? onProgress,
      void Function(String)? onFileProgress}) async {
    if (await dropChannel.isProcessRunning()) {
      logger.log('A process is already running. Please cancel it first.');
      return null;
    }

    final outputArchive = await _getUniqueArchiveName(outputFolder);
    final tempDir = await Directory(outputFolder).createTemp('archived');

    try {
      // Total number of paths
      int totalPaths = paths.length;

      // Copy files to temporary directory
      for (int i = 0; i < totalPaths; i++) {
        final path = paths[i];
        final destPath = '${tempDir.path}/';

        if (onFileProgress != null) {
          onFileProgress(path);
        }

        // Use cp because ditto won't work for some reason
        await executeNativeProcess('cp', [path, destPath]);

        // Calculate and update progress
        if (onProgress != null) {
          double progress =
              ((i + 1) / totalPaths) * 80; // First 80% for copying
          onProgress(progress);
        }
      }

      if (onFileProgress != null) {
        onFileProgress('Compressing...');
      }

      final result = await executeNativeProcess('ditto', [
        '-c',
        '-k',
        '--sequesterRsrc',
        '--zlibCompressionLevel=9',
        tempDir.path,
        outputArchive
      ]);

      final exitCode = result.exitCode;

      if (exitCode != 0) {
        logger.log('Error compressing files: Exit code $exitCode');
        throw Exception('Archive process failed with exit code: $exitCode');
      }

      if (onProgress != null) {
        onProgress(100);
      }

      // Open Finder and reveal the archive
      await executeNativeProcess('open', ['-R', outputArchive]);

      return outputArchive;
    } catch (e) {
      logger.log('Error during compression: $e');
      rethrow;
    } finally {
      // Clean up: remove the temporary directory
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        logger.log('Error deleting temporary directory: $e');
      }
    }
  }

  Future<String> _getUniqueArchiveName(String folder) async {
    String baseName = 'archive';
    String extension = '.zip';
    const int maxBaseLength = 200;

    // Ensure base name isn't too long
    if (baseName.length > maxBaseLength) {
      baseName = baseName.substring(0, maxBaseLength);
    }

    String fullPath = path.join(folder, '$baseName$extension');
    int counter = 1;

    while (await File(fullPath).exists()) {
      String newName = '$baseName (${counter++})';
      if (newName.length > maxBaseLength) {
        // Truncate the base name to make room for counter
        newName = '${baseName.substring(0, maxBaseLength - 5)} ($counter)';
      }
      fullPath = path.join(folder, '$newName$extension');
    }

    return fullPath;
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
    String pathWithoutExt = hasExtension
        ? filePath.substring(0, filePath.lastIndexOf('.'))
        : filePath;

    // Get directory and base name separately
    final directory = path.dirname(pathWithoutExt);
    String baseName = path.basename(pathWithoutExt);

    // Maximum length for the base name (excluding extension)
    // Windows has a 260 character path limit, using a conservative limit
    const int maxBaseLength = 200;

    if (baseName.length > maxBaseLength) {
      baseName = baseName.substring(0, maxBaseLength);
      pathWithoutExt = path.join(directory, baseName);
    }

    int counter = 0;
    String newPath;
    do {
      final String extensionToUse = fileExtension.startsWith('.')
          ? fileExtension.substring(1)
          : fileExtension;
      final String suffix0 = suffix ?? '';
      final String counter0 = counter > 0 ? ' ($counter)' : '';
      newPath = '$pathWithoutExt$suffix0$counter0.$extensionToUse';

      // If the path is still too long, truncate the base name further
      if (newPath.length > 250) {
        final int excess = newPath.length - 250;
        baseName = baseName.substring(0, baseName.length - excess);
        pathWithoutExt = path.join(directory, baseName);
        newPath = '$pathWithoutExt$suffix0$counter0.$extensionToUse';
      }

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
      logger.log('Getting media duration for: $filePath');
      final result = await executeNativeProcess(
        'ffprobe',
        args,
      );

      final duration = double.tryParse(result.stdout.toString().trim());
      if (duration != null) {
        return Duration(milliseconds: (duration * 1000).round());
      }
      return null;
    } catch (e) {
      logger.log('[Process.getMediaDuration] Error: $e');
      return null;
    }
  }

  Future<void> openFileLocation(String filePath) async {
    try {
      final result = await executeNativeProcess('open', ['-R', filePath]);
      if (result.exitCode != 0) {
        throw Exception(
            'Open command failed with exit code: ${result.exitCode}');
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
    final stopwatch = Stopwatch()..start();
    try {
      final ffmpegInstalled = await executeNativeProcess('which', ['ffmpeg']);
      final ffmpegTime = stopwatch.elapsed;
      logger
          .log('[Cli.setup] FFmpeg check took: ${ffmpegTime.inMilliseconds}ms');

      final imagemagickInstalled =
          await executeNativeProcess('which', ['magick']);
      final magickTime = stopwatch.elapsed;
      logger.log(
          '[Cli.setup] ImageMagick check took: ${magickTime.inMilliseconds}ms');

      final ytdlpInstalled = await executeNativeProcess('which', ['yt-dlp']);
      final ytdlpTime = stopwatch.elapsed;
      logger
          .log('[Cli.setup] yt-dlp check took: ${ytdlpTime.inMilliseconds}ms');

      final gallerydlInstalled =
          await executeNativeProcess('which', ['gallery-dl']);
      final gallerydlTime = stopwatch.elapsed;
      logger.log(
          '[Cli.setup] gallery-dl check took: ${gallerydlTime.inMilliseconds}ms');

      stopwatch.stop();
      logger.log(
          '[Cli.setup] Total check time: ${stopwatch.elapsed.inMilliseconds}ms');

      if (ffmpegInstalled.exitCode == 0 &&
          imagemagickInstalled.exitCode == 0 &&
          ytdlpInstalled.exitCode == 0 &&
          gallerydlInstalled.exitCode == 0) {
        onSuccess();
        return;
      }
    } catch (e) {
      logger.log('[Cli.setup] Somethong not installef: $e');
    }

    final completer = Completer<void>();
    String currentStep = '';
    double progress = 0.0;

    void updateProgress(String text) {
      // Remove ANSI escape codes and extra whitespace
      text = text.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '').trim();

      if (text.isEmpty) return;

      logger.log('[Cli.setup] Output: $text');

      final steps = [
        'Checking requirements...',
        'Installing Homebrew...',
        'Homebrew installed',
        'Installing FFmpeg...',
        'FFmpeg installed',
        'Installing ImageMagick...',
        'ImageMagick installed',
        'Installing yt-dlp...',
        'yt-dlp installed',
        'Installing gallery-dl...',
        'gallery-dl installed',
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
        'Installing yt-dlp',
        'yt-dlp installation completed',
        'Installing gallery-dl',
        'gallery-dl installation completed',
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

      // Handle tool-specific reinstall messages
      if (text.contains('FFmpeg exists but not working correctly')) {
        currentStep = 'Reinstalling FFmpeg...';
        onProgress(currentStep, progress);
      } else if (text.contains('yt-dlp not working')) {
        currentStep = 'Reinstalling yt-dlp...';
        onProgress(currentStep, progress);
      } else if (text.contains('gallery-dl not working')) {
        currentStep = 'Reinstalling gallery-dl...';
        onProgress(currentStep, progress);
      }

      // Handle errors
      if (text.contains('Error:')) {
        final errorMessage = text.substring(text.indexOf('Error:'));
        currentStep = 'Error: Installation failed';
        onError(errorMessage);
        completer.completeError(Exception(errorMessage));
      }

      if (text.contains(
          'All checks and installations are completed successfully')) {
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
    await executeNativeProcess('chmod', ['+x', scriptPath]);

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
