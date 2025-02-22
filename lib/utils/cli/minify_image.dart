part of '../cli.dart';

class _CliMinifyImage {
  Future<String?> minifyImage(
    String inputPath, {
    String? fileExtension,
    int quality = 95,
    required int downScale,
    int cropLeft = 0,
    int cropRight = 0,
    int cropTop = 0,
    int cropBottom = 0,
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

    final outputPath = cli._getUniqueFilePath(inputPath,
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

    // Add crop arguments if any crop value is non-zero
    if (cropLeft > 0 || cropRight > 0 || cropTop > 0 || cropBottom > 0) {
      args.addAll([
        '-crop',
        '+${cropLeft}+${cropTop}', 
        '-crop',
        '-${cropRight}-${cropBottom}',
      ]);
      logger.log('Applying crop values: L:$cropLeft R:$cropRight T:$cropTop B:$cropBottom');
    }

    if (downScale > 1) {
      args.addAll(['-resize', '$downScale%']);
      logger.log(
          'Applying downscale factor: $downScale ($downScale% of original size)');
    }

    // Only add quality argument if not lossless (quality < 100)
    if (quality < 100) {
      args.addAll(['-quality', quality.toString()]);
      logger.log('Applying quality: $quality');
    } else {
      logger.log('Using lossless quality (no compression)');
    }

    args.addAll(['-monitor', outputPath]);

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

      final result = await cli.run('magick', args);
      logger.log('Process completed with exit code: ${result.exitCode}');
      logger.log('Output: ${result.stdout}');
      logger.log('Error: ${result.stderr}');
      logger.log('Process completed with exit code: ${result.exitCode}');

      dropChannel.removeCliErrorCallback(callback);

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
}
