part of '../cli.dart';

class _CliDownloadMedia {
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

    final outputTemplate =
        path.join(outputDir, '%(uploader).30B - %(title).170B');

    final args = [
      '--no-mtime',
      '--progress',
      '--newline',
      '--restrict-filenames',
      '--windows-filenames',
      '--trim-filenames',
      '200',
      '-o',
      outputTemplate,
      urlString,
    ];

    try {
      logger.log('🚀 Launching yt-dlp process...');

      callback(String line) {
        if (onProgress != null) {
          if (line.contains('[hlsnative] Total fragments:')) {
            return;
          }

          final progressMatch =
              RegExp(r'\[download\]\s+(\d+\.?\d*)%.*\(frag\s+(\d+)\/(\d+)\)')
                  .firstMatch(line);
          if (progressMatch != null) {
            final percent = double.tryParse(progressMatch.group(1)!);
            final fragCurrent = int.tryParse(progressMatch.group(2)!);
            final fragTotal = int.tryParse(progressMatch.group(3)!);

            if (percent != null && fragCurrent != null && fragTotal != null) {
              final fragmentProgress = percent / 100;
              final overallProgress =
                  (fragCurrent - 1 + fragmentProgress) / fragTotal;

              onProgress(overallProgress);
              logger.log(
                  'Download progress: ${(overallProgress * 100).toStringAsFixed(1)}% (Fragment $fragCurrent/$fragTotal)');
            }
            return;
          }

          if (line.contains('[Merger]')) {
            onProgress(1.0);
            logger.log('Merging formats...');
            return;
          }

          if (line.contains('[download] 100% of')) {
            onProgress(1.0);
            logger.log('Download completed');
            return;
          }
        }
      }

      dropChannel.addCliOutputCallback(callback);

      final result = await cli.run('yt-dlp', args);

      dropChannel.removeCliOutputCallback(callback);

      if (result.exitCode != 0) {
        throw Exception(
            'yt-dlp process failed with exit code: ${result.exitCode}');
      }

      await cli.run('open', [outputDir]);
    } catch (e) {
      logger.log('❌ Critical error during download: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      cli.cancel();
      logger.log('=== Media Download Process Completed ===');
    }
  }

  Future<void> downloadMedia(
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
          if (line.contains('Download complete')) {
            onProgress(1.0);
            logger.log('Download completed');
            return;
          }

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

      final result = await cli.run('gallery-dl', args);

      dropChannel.removeCliOutputCallback(callback);

      if (result.exitCode != 0) {
        throw Exception(
            'gallery-dl process failed with exit code: ${result.exitCode}');
      }

      await cli.run('open', [outputDir]);
    } catch (e) {
      logger.log('❌ Critical error during download: $e');
      logger.log('Stack trace: ${StackTrace.current}');
      rethrow;
    } finally {
      logger.log('Cleaning up process resources');
      cli.cancel();
      logger.log('=== Media Download Process Completed ===');
    }
  }
}
