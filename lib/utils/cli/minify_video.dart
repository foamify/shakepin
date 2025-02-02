part of '../cli.dart';

class _CliMinifyVideo {
  Future<String?> minifyVideo(
    String inputPath, {
    String? format,
    String quality = 'medium',
    bool enableHardwareAcceleration = true,
    int downScale = 100,
    void Function(double)? onProgress,
  }) async {
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
        cli._getUniqueFilePath(inputPath, inputExtension: format);
    await logger.log('[Process.minifyVideo] Output path: $finalOutputPath');

    List<String> ffmpegArgs = [];

    if (enableHardwareAcceleration) {
      ffmpegArgs.addAll(['-hwaccel', 'auto']);
    }

    ffmpegArgs.addAll([
      '-progress',
      'pipe:2',
      '-stats',
      '-i',
      inputPath,
    ]);

    List<String> filterArgs = [];
    if (downScale < 100) {
      filterArgs
          .addAll(['-vf', 'scale=iw*${downScale / 100}:ih*${downScale / 100}']);
      await logger
          .log('[Process.minifyVideo] Adding downscale filter: $downScale%');
    }

    switch (format.toLowerCase()) {
      case '.webm':
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
          'realtime',
          '-cpu-used',
          '4',
          '-row-mt',
          '1',
          '-tile-columns',
          '2',
          '-frame-parallel',
          '1',
          '-threads',
          '0',
          '-c:a',
          'libopus',
          '-b:a',
          '96k',
        ]);
        if (filterArgs.isNotEmpty) ffmpegArgs.addAll(filterArgs);

      case '.gif':
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
          'main',
          '-level',
          '4.0',
          '-tune',
          'fastdecode',
          '-movflags',
          '+faststart',
          '-y',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
          '-threads',
          '0',
        ]);
        if (filterArgs.isNotEmpty) ffmpegArgs.addAll(filterArgs);
    }

    ffmpegArgs.add(finalOutputPath);

    try {
      final duration = await cli.getMediaDuration(inputPath);
      if (duration == null) {
        throw Exception('Could not determine video duration');
      }
      final durationInSeconds = duration.inMilliseconds / 1000.0;

      void callback(String line) {
        if (onProgress != null) {
          final timeMatch =
              RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)|\btime=\s*(\d+\.\d+)')
                  .firstMatch(line);
          if (timeMatch != null) {
            double currentTime;
            if (timeMatch.group(1) != null) {
              final hours = int.parse(timeMatch.group(1)!);
              final minutes = int.parse(timeMatch.group(2)!);
              final seconds = int.parse(timeMatch.group(3)!);
              final milliseconds = int.parse(timeMatch.group(4)!);
              currentTime =
                  hours * 3600 + minutes * 60 + seconds + milliseconds / 100;
            } else {
              currentTime = double.parse(timeMatch.group(5)!);
            }
            final progress = currentTime / durationInSeconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        }
      }

      dropChannel.addCliErrorCallback(callback);

      await cli.run('ffmpeg', ffmpegArgs);

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
    }
  }
}
