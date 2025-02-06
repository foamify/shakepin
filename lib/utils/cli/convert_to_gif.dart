part of '../cli.dart';

class _CliConvertToGif {
  Future<String?> convertToGif(
    String inputPath, {
    int quality = 90,
    int fps = 30,
    int downScale = 100,
    void Function(double)? onProgress,
  }) async {
    try {
      // Get video dimensions using ffprobe
      final dimensionsResult = await cli.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=width,height',
        '-of',
        'csv=s=x:p=0',
        inputPath
      ]);

      final dimensions = dimensionsResult.stdout.toString().trim().split('x');
      final width = int.parse(dimensions[0]);
      final height = int.parse(dimensions[1]);

      // Calculate new dimensions based on downScale percentage
      final newWidth = (width * downScale / 100).round();
      final newHeight = (height * downScale / 100).round();

      final outputPath = cli._getUniqueFilePath(
        inputPath,
        suffix: '_converted',
        inputExtension: '.gif',
      );

      final args = [
        inputPath,
        '-o',
        outputPath,
        '--quality',
        quality.toString(),
        '--fps',
        fps.toString(),
        '--width',
        newWidth.toString(),
        '--height',
        newHeight.toString(),
      ];

      final result = await cli.run('gifski', args);

      if (result.exitCode != 0) {
        throw Exception('Failed to convert to GIF: ${result.stderr}');
      }

      await cli.run('open', ['-R', outputPath]);

      return outputPath;
    } catch (e) {
      logger.log('[_CliConvertToGif] Error: $e');
      rethrow;
    }
  }
}
