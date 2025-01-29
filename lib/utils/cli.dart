import 'dart:async';
import 'dart:convert';
import 'dart:io' hide Process;

import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/state.dart';
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

enum SetupStep {
  checkingHomebrew(label: 'Checking Homebrew...', progress: 0.1),
  installingHomebrew(label: 'Installing Homebrew...', progress: 0.2),
  homebrewInstalled(label: 'Homebrew installed', progress: 0.3),
  checkingFfmpeg(label: 'Checking FFmpeg...', progress: 0.4),
  installingFfmpeg(label: 'Installing FFmpeg...', progress: 0.5),
  ffmpegInstalled(label: 'FFmpeg installed', progress: 0.6),
  checkingImageMagick(label: 'Checking ImageMagick...', progress: 0.65),
  installingImageMagick(label: 'Installing ImageMagick...', progress: 0.7),
  imageMagickInstalled(label: 'ImageMagick installed', progress: 0.8),
  checkingYtDlp(label: 'Checking yt-dlp...', progress: 0.85),
  installingYtDlp(label: 'Installing yt-dlp...', progress: 0.9),
  ytDlpInstalled(label: 'yt-dlp installed', progress: 0.95),
  checkingGalleryDl(label: 'Checking gallery-dl...', progress: 0.96),
  installingGalleryDl(label: 'Installing gallery-dl...', progress: 0.98),
  galleryDlInstalled(label: 'gallery-dl installed', progress: 0.99),
  finishingUp(label: 'Finishing up...', progress: 1.0),
  ;

  final String label;
  final double progress;

  const SetupStep({required this.label, required this.progress});
}

class Cli {
  Cli._() {
    init();
  }

  void init() {}

  void dispose() {
    cancel();
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
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    bool noThrow = false,
  }) async {
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

      if (result.exitCode != 0 && !noThrow) {
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

      final result = await run('yt-dlp', args);

      dropChannel.removeCliOutputCallback(callback);

      if (result.exitCode != 0) {
        throw Exception(
            'yt-dlp process failed with exit code: ${result.exitCode}');
      }

      // Open the downloads folder
      await run('open', [outputDir]);
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

      final result = await run('gallery-dl', args);

      dropChannel.removeCliOutputCallback(callback);

      if (result.exitCode != 0) {
        throw Exception(
            'gallery-dl process failed with exit code: ${result.exitCode}');
      }

      // Open the downloads folder
      await run('open', [outputDir]);
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

      final result = await run('ffmpeg', ffmpegArgs);

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

      final result = await run('magick', args.map((e) => "'$e'").toList());
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

  Future<String?> minifyImage(
    String inputPath, {
    String? fileExtension,
    int quality = 95,
    required int downScale,
    void Function(double)? onProgress,
  }) async {
    logger.log('=== Starting Image Minification Process ===');
    logger.log('Input path: $inputPath');
    logger.log('Target quality: $quality');
    logger.log('Target format: ${fileExtension ?? "same as input"}');

    if (await dropChannel.isProcessRunning()) {
      logger
          .log('⚠️ Process conflict: Another minification process is running');
      logger.log('Aborting new minification request');
      return null;
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

      final result = await run('magick', args.map((e) => "'$e'").toList());
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
      return outputPath;
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

  Future<String?> minifyVideo(String inputPath,
      {String? format,
      String quality = 'medium',
      bool enableHardwareAcceleration = true,
      int downScale = 100, // Add this parameter
      void Function(double)? onProgress}) async {
    await logger.log('[Process.minifyVideo] Starting video minification');
    if (await dropChannel.isProcessRunning()) {
      await logger.log('A process is already running. Please cancel it first.');
      return null;
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

    // Add downscaling filter if needed
    List<String> filterArgs = [];
    if (downScale < 100) {
      filterArgs
          .addAll(['-vf', 'scale=iw*${downScale / 100}:ih*${downScale / 100}']);
      await logger
          .log('[Process.minifyVideo] Adding downscale filter: ${downScale}%');
    }

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
        if (filterArgs.isNotEmpty) {
          ffmpegArgs.addAll(filterArgs);
        }

      case 'gif':
        await logger.log('[Process.minifyVideo] Using GIF encoding');
        // For gif, merge the scale filter with existing filters
        if (downScale < 100) {
          ffmpegArgs.addAll([
            '-vf',
            'fps=10,scale=iw*${downScale / 100}:ih*${downScale / 100},split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse',
          ]);
        } else {
          ffmpegArgs.addAll([
            '-vf',
            'fps=10,scale=500:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse',
            '-loop',
            '0',
          ]);
        }

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
        if (filterArgs.isNotEmpty) {
          ffmpegArgs.addAll(filterArgs);
        }
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

      final result = await run('ffmpeg', ffmpegArgs);
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

      return finalOutputPath;
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
        await run('cp', [path, destPath]);

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

      final result = await run('ditto', [
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
      await run('open', ['-R', outputArchive]);

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
      final result = await run(
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
      final result = await run('open', ['-R', filePath]);
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
    required Function(SetupStep step) onProgress,
    required Function(String error, SetupStep step)
        onError, // Modified signature
    required Function() onSuccess,
  }) async {
    logger.log('[Cli.setup] Starting setup...');
    final stopwatch = Stopwatch()..start();

    void updateProgress(SetupStep step) {
      logger.log('[Cli.setup] Progress: ${step.label} (${step.progress})');
      onProgress(step);
    }

    // Check if Homebrew is installed
    try {
      updateProgress(SetupStep.checkingHomebrew);
      final brewResult = await run('which', ['brew'], noThrow: true);
      if (brewResult.exitCode != 0) {
        updateProgress(SetupStep.installingHomebrew);

        const installScript =
            'yes \'\' | /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"';
        final result = await run(installScript, [], noThrow: true);

        if (result.exitCode != 0) {
          onError('Failed to install Homebrew: ${result.stderr}',
              SetupStep.installingHomebrew);
          return;
        }
        updateProgress(SetupStep.homebrewInstalled);
      }

      // Check and install FFmpeg
      updateProgress(SetupStep.checkingFfmpeg);
      final ffmpegResult = await run('which', ['ffmpeg'], noThrow: true);
      if (ffmpegResult.exitCode != 0) {
        updateProgress(SetupStep.installingFfmpeg);
        final result = await run('brew', ['install', 'ffmpeg'], noThrow: true);
        if (result.exitCode != 0) {
          onError('Failed to install FFmpeg', SetupStep.installingFfmpeg);
          return;
        }
      }
      updateProgress(SetupStep.ffmpegInstalled);

      // Check and install ImageMagick
      updateProgress(SetupStep.checkingImageMagick);
      final magickResult = await run('which', ['magick'], noThrow: true);
      if (magickResult.exitCode != 0) {
        updateProgress(SetupStep.installingImageMagick);
        final result =
            await run('brew', ['install', 'imagemagick'], noThrow: true);
        if (result.exitCode != 0) {
          onError(
              'Failed to install ImageMagick', SetupStep.installingImageMagick);
          return;
        }
      }
      updateProgress(SetupStep.imageMagickInstalled);

      // Check and install yt-dlp
      updateProgress(SetupStep.checkingYtDlp);
      final ytdlpResult = await run('which', ['yt-dlp'], noThrow: true);
      if (ytdlpResult.exitCode != 0) {
        updateProgress(SetupStep.installingYtDlp);
        final result = await run('brew', ['install', 'yt-dlp'], noThrow: true);
        if (result.exitCode != 0) {
          onError('Failed to install yt-dlp', SetupStep.installingYtDlp);
          return;
        }
      }
      updateProgress(SetupStep.ytDlpInstalled);

      // Check and install gallery-dl
      updateProgress(SetupStep.checkingGalleryDl);
      final galleryResult = await run('which', ['gallery-dl'], noThrow: true);
      if (galleryResult.exitCode != 0) {
        updateProgress(SetupStep.installingGalleryDl);
        final result =
            await run('brew', ['install', 'gallery-dl'], noThrow: true);
        if (result.exitCode != 0) {
          onError(
              'Failed to install gallery-dl', SetupStep.installingGalleryDl);
          return;
        }
      }
      updateProgress(SetupStep.galleryDlInstalled);
      updateProgress(SetupStep.finishingUp);

      // Verify all installations
      final List<String> verifyCommands = [
        'ffmpeg -version',
        'magick -version',
        'yt-dlp --version',
        'gallery-dl --version'
      ];

      for (final cmd in verifyCommands) {
        final parts = cmd.split(' ');
        final result = await run(parts[0], parts.sublist(1), noThrow: true);
        if (result.exitCode != 0) {
          onError('Failed to verify ${parts[0]} installation',
              setupStep.value ?? SetupStep.checkingHomebrew);
          return;
        }
      }

      stopwatch.stop();
      logger.log(
          '[Cli.setup] Setup completed in ${stopwatch.elapsed.inSeconds}s');
      onSuccess();
    } catch (e) {
      logger.log('[Cli.setup] Error: $e');
      onError(e.toString(), setupStep.value ?? SetupStep.checkingHomebrew);
    }
  }
}

void initCli() {
  if (setupError() != null) {
    setupError.value = null;
    setupSuccess.value = null;
    setupStep.value = null;
  }
  cli.setup(
    onProgress: (step) {
      logger.log('Setup progress: ${step.label} (${step.progress})');
      setupStep.value = step;
    },
    onError: (error, step) {
      logger.log('Setup error at ${step.label}: $error');
      setupError.value = step;
      setupSuccess.value = false;
    },
    onSuccess: () {
      logger.log('Setup completed');
      setupSuccess.value = true;
    },
  );
}
