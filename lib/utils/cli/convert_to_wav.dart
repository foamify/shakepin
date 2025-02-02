part of '../cli.dart';

class _CliConvertToWav {
  Future<String?> convertToWav(
    String inputPath, {
    Duration? startTime,
    Duration? endTime,
    void Function(double)? onProgress,
  }) async {
    logger.log('=== Starting WAV Conversion Process ===');
    logger.log('Input path: $inputPath');

    if (startTime != null) {
      logger.log('Start time: ${_formatDuration(startTime)}');
    }
    if (endTime != null) logger.log('End time: ${_formatDuration(endTime)}');

    if (await dropChannel.isProcessRunning()) {
      logger.log('⚠️ Process conflict: Another conversion process is running');
      logger.log('Aborting new conversion request');
      return null;
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
      duration = await cli.getMediaDuration(inputPath);
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
            final progress = currentTime / durationInSeconds;

            onProgress(progress.clamp(0.0, 1.0));
            logger.log(
                'Conversion progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        }
      }

      dropChannel.addCliOutputCallback(callback);

      final result = await cli.run('ffmpeg', ffmpegArgs);

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

      return outputPath;
    } catch (e) {
      logger.log('❌ Critical error during conversion: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      logger.log('=== WAV Conversion Process Completed ===');
    }
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}';
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

    final directory = path.dirname(pathWithoutExt);
    String baseName = path.basename(pathWithoutExt);

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
}
