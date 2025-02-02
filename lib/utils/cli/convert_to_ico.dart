part of '../cli.dart';

class _CliConvertToIco {
  /// Converts an image file to ICO format using ImageMagick
  ///
  /// The input file can be any image format supported by ImageMagick
  /// The output will be an ICO file with multiple sizes (16, 32, 48, 64, 128, 256, 512)
  Future<String?> convertToIco(String inputPath,
      {void Function(double)? onProgress}) async {
    logger.log('=== Starting ICO Conversion Process ===');
    logger.log('Input path: $inputPath');

    if (await dropChannel.isProcessRunning()) {
      logger.log('⚠️ Process conflict: Another conversion process is running');
      throw Exception('Another process is already running');
    }

    final outputPath =
        cli._getUniqueFilePath(inputPath, suffix: '', inputExtension: 'ico');
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

      final result = await cli.run('magick', args);

      if (result.exitCode != 0) {
        logger.log('❌ Process failed with exit code: ${result.exitCode}');
        throw Exception(
            'ImageMagick process failed with exit code: ${result.exitCode}');
      }

      // Call progress callback with completion
      if (onProgress != null) {
        onProgress(1.0);
      }

      logger.log('✅ ICO conversion completed successfully');
      return outputPath;
    } catch (e) {
      logger.log('❌ Critical error during ICO conversion: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      logger.log('=== ICO Conversion Process Completed ===');
    }
  }

  /// Validates if the input file is a supported image format
  bool _isValidInputFormat(String filePath) {
    final validExtensions = [
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.bmp',
      '.tiff',
      '.webp'
    ];
    final extension = path.extension(filePath).toLowerCase();
    return validExtensions.contains(extension);
  }

  /// Gets information about the input image using ImageMagick
  Future<Map<String, dynamic>> _getImageInfo(String inputPath) async {
    try {
      final result = await cli
          .run('magick', ['identify', '-format', '%w,%h,%m', inputPath]);

      final parts = result.stdout.toString().trim().split(',');
      return {
        'width': int.parse(parts[0]),
        'height': int.parse(parts[1]),
        'format': parts[2],
      };
    } catch (e) {
      logger.log('Error getting image info: $e');
      rethrow;
    }
  }
}
