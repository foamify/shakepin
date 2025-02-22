part of '../cli.dart';

class _CliVideoUtils {
  /// Gets video resolution using FFprobe
  Future<({int width, int height})?> getVideoResolution(String path) async {
    try {
      await logger
          .log('[Process.getVideoResolution] Getting resolution for: $path');
      final result = await cli.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=width,height',
        '-of',
        'csv=s=x:p=0',
        path
      ]);

      final parts = (result.stdout as String).trim().split('x');
      if (parts.length == 2) {
        final width = int.parse(parts[0]);
        final height = int.parse(parts[1]);
        await logger
            .log('[Process.getVideoResolution] Resolution: ${width}x$height');
        return (width: width, height: height);
      }
      await logger
          .log('[Process.getVideoResolution] Could not parse resolution');
      return null;
    } catch (e) {
      await logger.log('[Process.getVideoResolution] Error: $e');
      return null;
    }
  }

  /// Gets all keyframes from video using FFprobe
  Future<List<Duration>> getVideoKeyframes(String path) async {
    try {
      await logger
          .log('[Process.getVideoKeyframes] Getting keyframes for: $path');
      final result = await cli.run('ffprobe', [
        '-v',
        'error',
        '-skip_frame',
        'nokey',
        '-show_entries',
        'frame=pts_time',
        '-select_streams',
        'v',
        '-of',
        'csv=p=0',
        path
      ]);

      final keyframes = (result.stdout as String)
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .map((s) => Duration(milliseconds: (double.parse(s) * 1000).round()))
          .toList();

      await logger.log(
          '[Process.getVideoKeyframes] Found ${keyframes.length} keyframes');
      return keyframes;
    } catch (e) {
      await logger.log('[Process.getVideoKeyframes] Error: $e');
      return [];
    }
  }

  /// Extract a frame at specific timestamp using FFmpeg
  Future<String?> extractFrame(String path, Duration timestamp) async {
    final outputPath = '${path}_frame_${timestamp.inMilliseconds}.jpg';
    try {
      await logger.log(
          '[Process.extractFrame] Extracting frame at ${timestamp.inSeconds}s from: $path');
      await cli.run('ffmpeg', [
        '-ss',
        '${timestamp.inMilliseconds / 1000}',
        '-i',
        path,
        '-vframes',
        '1',
        '-q:v',
        '2',
        outputPath
      ]);
      await logger
          .log('[Process.extractFrame] Extracted frame to: $outputPath');
      return outputPath;
    } catch (e) {
      await logger.log('[Process.extractFrame] Error: $e');
      return null;
    }
  }
}
