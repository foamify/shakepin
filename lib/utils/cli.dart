import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';

part 'cli/archive.dart';
part 'cli/extract_audio.dart';
part 'cli/convert_to_ico.dart';
part 'cli/convert_to_gif.dart';
part 'cli/download_media.dart';
part 'cli/minify_image.dart';
part 'cli/minify_video.dart';
part 'cli/setup.dart';
part 'cli/video_utils.dart';

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
  Cli._() {
    init();
  }

  final _archive = _CliArchive();
  final _extractAudio = _CliExtractAudio();
  final _convertToIco = _CliConvertToIco();
  final _convertToGif = _CliConvertToGif();
  final _downloadMedia = _CliDownloadMedia();
  final _minifyImage = _CliMinifyImage();
  final _minifyVideo = _CliMinifyVideo();
  final _setup = _CliSetup();
  final _videoUtils = _CliVideoUtils();

  void init() {}

  void dispose() {
    cancel();
  }

  void cancel() {
    dropChannel.cancelProcess();
    logger.log('Process canceled');
  }

  String _normalizePath(String filePath) {
    if (Platform.isWindows) {
      // Keep Windows backslashes but ensure proper escaping
      return filePath.replaceAll('/', '\\');
    }
    return filePath;
  }

  String _normalizeExecutablePath(String command) {
    if (Platform.isWindows) {
      // Handle Windows executable paths
      if (!command.toLowerCase().endsWith('.exe')) {
        command = '$command.exe';
      }

      // If path starts with /drive_letter/, convert to DRIVE_LETTER:\
      if (RegExp(r'^/[a-zA-Z]/').hasMatch(command)) {
        command = '${command[1].toUpperCase()}:${command.substring(2)}'
            .replaceAll('/', '\\');
      }

      return command;
    }
    return command;
  }

  /// Executes a one-off native process with basic error handling and logging
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    bool noThrow = false,
  }) async {
    command = _normalizeExecutablePath(command);

    // Handle path arguments separately from other arguments
    final normalizedArgs = arguments.map((arg) {
      if (arg.contains('\\') || arg.contains('/')) {
        return _normalizePath(arg);
      }
      return arg;
    }).toList();

    logger.log(
        '[Native Process] Starting: $command ${normalizedArgs.map((e) => "'$e'").join(' ')}');

    // Check if another process is running
    if (await dropChannel.isProcessRunning()) {
      const error = 'Another process is already running';
      logger.log('[Native Process] Error: $error');
      throw ProcessException(command, normalizedArgs, error, -1);
    }

    try {
      final result = await dropChannel.startProcess(
        command,
        Platform.isWindows
            ? normalizedArgs
            : normalizedArgs.map((e) => "'$e'").toList(),
      );

      if (result.exitCode != 0 && !noThrow) {
        final error =
            'Process failed with exit code: ${result.exitCode}\nError: ${result.stderr}';
        logger.log('[Native Process] $error');
        throw ProcessException(command, normalizedArgs, error, result.exitCode);
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

  Future<void> downloadVideo(String urlString,
      {void Function(double)? onProgress}) async {
    await _downloadMedia.downloadVideo(urlString, onProgress: onProgress);
  }

  Future<void> downloadMedia(String urlString,
      {void Function(double)? onProgress}) async {
    await _downloadMedia.downloadMedia(urlString, onProgress: onProgress);
  }

  // MARK: - Convert to ICO

  Future<String?> convertToIco(String inputPath,
      {void Function(double)? onProgress}) async {
    return _convertToIco.convertToIco(inputPath, onProgress: onProgress);
  }

  // MARK: - Convert to GIF

  Future<String?> convertToGif(
    String inputPath, {
    int quality = 90,
    int fps = 30,
    int downScale = 100,
    void Function(double)? onProgress,
  }) async {
    return _convertToGif.convertToGif(
      inputPath,
      quality: quality,
      fps: fps,
      downScale: downScale,
      onProgress: onProgress,
    );
  }

  // MARK: - Minify Image

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
    return _minifyImage.minifyImage(
      inputPath,
      fileExtension: fileExtension,
      quality: quality,
      downScale: downScale,
      cropLeft: cropLeft,
      cropRight: cropRight,
      cropTop: cropTop,
      cropBottom: cropBottom,
      onProgress: onProgress,
    );
  }

  // MARK: - Minify Video

  Future<String?> minifyVideo(String inputPath, {
    String? format,
    String quality = 'medium', 
    bool enableHardwareAcceleration = true,
    int downScale = 100,
    int cropLeft = 0,
    int cropRight = 0, 
    int cropTop = 0,
    int cropBottom = 0,
    void Function(double)? onProgress,
  }) async {
    return _minifyVideo.minifyVideo(
      inputPath,
      format: format,
      quality: quality,
      enableHardwareAcceleration: enableHardwareAcceleration,
      downScale: downScale,
      cropLeft: cropLeft,
      cropRight: cropRight,
      cropTop: cropTop,
      cropBottom: cropBottom,
      onProgress: onProgress,
    );
  }

  Future<String?> archiveFiles(List<String> paths, String outputFolder,
      {ArchiveFormat format = ArchiveFormat.zip,
      int compressionLevel = 6,
      String? password,
      void Function(double)? onProgress,
      void Function(String)? onFileProgress}) async {
    return _archive.archiveFiles(
      paths,
      outputFolder,
      format: format,
      compressionLevel: compressionLevel,
      encryption:
          password != null ? EncryptionOptions(password: password) : null,
      onProgress: onProgress,
      onFileProgress: onFileProgress,
      run: run,
    );
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

  Future<Duration?> getMediaDuration(String filePath) async {
    final normalizedPath = _normalizePath(filePath);
    final args = [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      normalizedPath,
    ];

    try {
      logger.log('Getting media duration for: $normalizedPath');
      final result = await run(
        'ffprobe',
        args,
        noThrow: true, // Add this to handle errors more gracefully
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
    required Function(String error, SetupStep step) onError,
    required Function() onSuccess,
  }) async {
    await _setup.setup(
      onProgress: onProgress,
      onError: onError,
      onSuccess: onSuccess,
      run: run,
    );
  }

  Future<List<String>> extractAudio(
    List<String> paths, {
    AudioFormat format = AudioFormat.wav,
    int? sampleRate,
    Duration? startTime,
    Duration? endTime,
    void Function(double)? onProgress,
  }) =>
      _extractAudio.extractAudio(
        paths,
        format: format,
        sampleRate: sampleRate,
        startTime: startTime,
        endTime: endTime,
        onProgress: onProgress,
      );

  Future<({int width, int height})?> getVideoResolution(String path) =>
      _videoUtils.getVideoResolution(path);
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
