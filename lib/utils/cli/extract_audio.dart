part of '../cli.dart';

class AudioFormat {
  final String extension;
  final String codec;
  final List<String> ffmpegArgs;
  final int sampleRate;

  const AudioFormat({
    required this.extension,
    required this.codec,
    required this.ffmpegArgs,
    this.sampleRate = 16000,
  });

  List<String> getFFmpegArgs({int? sampleRate}) {
    return [
      ...ffmpegArgs,
      '-ar',
      '${sampleRate ?? this.sampleRate}',
    ];
  }

  static const wav = AudioFormat(
    extension: 'wav',
    codec: 'pcm_s16le',
    ffmpegArgs: ['-acodec', 'pcm_s16le', '-ac', '1'],
  );

  static const mp3 = AudioFormat(
    extension: 'mp3',
    codec: 'libmp3lame',
    ffmpegArgs: ['-acodec', 'libmp3lame', '-q:a', '2'],
  );

  static const aac = AudioFormat(
    extension: 'm4a',
    codec: 'aac',
    ffmpegArgs: ['-acodec', 'aac', '-b:a', '192k'],
  );

  static const List<AudioFormat> values = [wav, mp3, aac];
}

class _CliExtractAudio {
  Future<List<String>> extractAudio(
    List<String> inputPaths, {
    AudioFormat format = AudioFormat.wav,
    int? sampleRate,
    Duration? startTime,
    Duration? endTime,
    void Function(double)? onProgress,
  }) async {
    logger.log('=== Starting Audio Extraction Process ===');
    logger.log('Input paths: ${inputPaths.join(", ")}');
    logger.log('Output format: ${format.extension}');

    if (startTime != null) {
      logger.log('Start time: ${_formatDuration(startTime)}');
    }
    if (endTime != null) logger.log('End time: ${_formatDuration(endTime)}');

    if (await dropChannel.isProcessRunning()) {
      logger.log('⚠️ Process conflict: Another extraction process is running');
      logger.log('Aborting new extraction request');
      return [];
    }

    List<String> outputPaths = [];
    int totalFiles = inputPaths.length;
    int processedFiles = 0;
    
    for (int i = 0; i < totalFiles; i++) {
      String inputPath = inputPaths[i];
      logger.log('Processing file ${i+1}/$totalFiles: $inputPath');
      
      final inputFile = File(inputPath);
      if (!inputFile.existsSync()) {
        logger.log('❌ Error: Input file not found at path: $inputPath');
        processedFiles++; // Count as processed for progress calculation
        continue;
      }

      final outputPath = _getUniqueFilePath(inputPath,
          suffix: '_audio', inputExtension: format.extension);
      logger.log('Generated output path: $outputPath');

      // First try direct extraction without progress tracking
      // This works better for files with special characters in names
      try {
        logger.log('Attempting extraction for file with potential special characters');
        final extractedPath = await _extractWithoutProgress(
          inputPath, 
          outputPath, 
          format, 
          sampleRate, 
          startTime, 
          endTime
        );
        
        if (extractedPath != null) {
          logger.log('✅ Successfully extracted audio without progress tracking');
          outputPaths.add(extractedPath);
          
          // Update progress
          processedFiles++;
          if (onProgress != null) {
            final overallProgress = processedFiles / totalFiles;
            onProgress(overallProgress.clamp(0.0, 1.0));
          }
          
          continue; // Skip to next file
        }
      } catch (e) {
        logger.log('⚠️ Initial extraction attempt failed: $e');
        // Fall through to try the second method
      }

      // If direct extraction failed, try with progress tracking
      Duration? duration;
      try {
        // Copy file to temp location with simple name
        final tempDir = await Directory.systemTemp.createTemp('audio_extract_');
        final extension = path.extension(inputPath);
        final tempFile = File(path.join(tempDir.path, 'input$extension'));
        
        try {
          await inputFile.copy(tempFile.path);
          logger.log('Created temporary file: ${tempFile.path}');
          
          // Get duration from temp file
          duration = await cli.getMediaDuration(tempFile.path);
          logger.log('Media duration from temp file: ${duration?.toString() ?? "Unknown"}');
          
          // Clean up
          try {
            await tempDir.delete(recursive: true);
          } catch (e) {
            logger.log('Warning: Failed to clean up temp directory: $e');
          }
        } catch (e) {
          logger.log('Error creating temp file: $e');
          // Try with original path as fallback
          duration = await cli.getMediaDuration(inputPath);
        }
      } catch (e) {
        logger.log('❌ Error getting media duration: $e');
      }

      if (duration == null) {
        logger.log('❌ Could not determine media duration for: $inputPath');
        
        // Skip this file and update progress
        processedFiles++;
        if (onProgress != null) {
          final overallProgress = processedFiles / totalFiles;
          onProgress(overallProgress.clamp(0.0, 1.0));
        }
        continue;
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
        ...format.getFFmpegArgs(sampleRate: sampleRate),
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
              final fileProgress = currentTime / durationInSeconds;
              
              // Calculate overall progress across all files
              final overallProgress = (processedFiles + fileProgress.clamp(0.0, 1.0)) / totalFiles;
              
              onProgress(overallProgress.clamp(0.0, 1.0));
              logger.log(
                  'Extraction progress: File ${i+1}/$totalFiles - ${(fileProgress * 100).toStringAsFixed(1)}%, Overall: ${(overallProgress * 100).toStringAsFixed(1)}%');
            }
          }
        }

        dropChannel.addCliOutputCallback(callback);

        final result = await cli.run('ffmpeg', ffmpegArgs);

        dropChannel.removeCliOutputCallback(callback);

        if (result.exitCode != 0) {
          logger.log('❌ Process failed with exit code: ${result.exitCode}');
          processedFiles++;
          continue;
        }

        final outputFile = File(outputPath);
        if (outputFile.existsSync()) {
          final outputFileSize = await outputFile.length();
          logger.log(
              'Output file size: ${(outputFileSize / 1024).toStringAsFixed(2)} KB');
          outputPaths.add(outputPath);
        } else {
          logger.log('❌ Warning: Output file was not created');
        }
      } catch (e) {
        logger.log('❌ Critical error during extraction: $e');
        logger.log('Stack trace: ${StackTrace.current}');
      }
      
      processedFiles++;
    }

    if (onProgress != null) {
      onProgress(1.0);
    }
    
    logger.log('Completed processing ${outputPaths.length}/$totalFiles files');
    logger.log('=== Audio Extraction Process Completed ===');
    
    return outputPaths;
  }
  
  Future<Duration?> _getMediaDuration(String filePath) async {
    try {
      // Create a temporary file with a simple name to avoid special character issues
      final tempDir = await Directory.systemTemp.createTemp('audio_extract_');
      final extension = path.extension(filePath);
      final tempFile = File(path.join(tempDir.path, 'input$extension'));
      
      // Create a symbolic link or copy the file to the temporary location
      try {
        await File(filePath).copy(tempFile.path);
        logger.log('Created temporary file: ${tempFile.path}');
      } catch (e) {
        logger.log('Error creating temp file, using original path: $e');
        // If copy fails, try with the original path
        return cli.getMediaDuration(filePath);
      }
      
      // Get duration using the temp file with simple name
      final duration = await cli.getMediaDuration(tempFile.path);
      
      // Clean up temp directory
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        logger.log('Warning: Failed to clean up temp directory: $e');
      }
      
      return duration;
    } catch (e) {
      logger.log('Error in _getMediaDuration: $e');
      return null;
    }
  }
  
  Future<String?> _extractWithoutProgress(
    String inputPath,
    String outputPath,
    AudioFormat format,
    int? sampleRate,
    Duration? startTime,
    Duration? endTime,
  ) async {
    List<String> ffmpegArgs = ['-i', inputPath];

    if (startTime != null) {
      ffmpegArgs.addAll(['-ss', _formatDuration(startTime)]);
    }
    if (endTime != null) {
      ffmpegArgs.addAll(['-to', _formatDuration(endTime)]);
    }

    ffmpegArgs.addAll([
      ...format.getFFmpegArgs(sampleRate: sampleRate),
      '-y',
      outputPath,
    ]);

    logger.log('Attempting extraction without progress tracking');
    logger.log('FFmpeg command arguments: ${ffmpegArgs.join(" ")}');

    try {
      final result = await cli.run('ffmpeg', ffmpegArgs, noThrow: true);

      if (result.exitCode != 0) {
        logger.log('❌ Process failed with exit code: ${result.exitCode}');
        return null;
      }

      final outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        final outputFileSize = await outputFile.length();
        logger.log('Output file size: ${(outputFileSize / 1024).toStringAsFixed(2)} KB');
        return outputPath;
      } else {
        logger.log('❌ Warning: Output file was not created');
        return null;
      }
    } catch (e) {
      logger.log('❌ Error during extraction without progress: $e');
      return null;
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
