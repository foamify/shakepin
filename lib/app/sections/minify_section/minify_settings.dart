import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:shakepin/widgets/native_dropdown_button.dart';

class MinifySettings extends StatefulWidget {
  const MinifySettings({super.key});

  @override
  State<MinifySettings> createState() => _MinifySettingsState();
}

class _MinifySettingsState extends State<MinifySettings> {
  var _videoQuality = VideoQuality.goodQuality;
  var _videoFormat = VideoFormat.sameAsInput;
  var _videoDownscale = VideoDownscale.sameAsInput; // Add this
  var _imageQuality = ImageQuality.normal;
  var _imageFormat = ImageFormat.sameAsInput;
  var _imageDownscale = ImageDownscale.sameAsInput; // Add this line

  bool get disabled =>
      !selectedItems().containsImage && !selectedItems().containsVideo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge([
          items,
          selectedItems,
          minifyInProgress,
          minifyOneFileProgress,
          processedFiles,
          totalFiles,
          minifiedFiles,
          errorMessages,
        ]),
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  if (selectedItems().containsVideo)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: MacosColors.systemGrayColor
                                .withValues(alpha: .2)),
                        borderRadius: BorderRadius.circular(6),
                        color: MacosColors.controlColor
                            .resolvedColor(context)
                            .withValues(alpha: .03),
                      ),
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('Video quality'),
                              const Spacer(),
                              NativeDropdownButton(
                                value: _videoQuality,
                                items: VideoQuality.values
                                    .map((quality) =>
                                        NativeDropdownItem<VideoQuality>(
                                            value: quality,
                                            label: quality.name))
                                    .toList(),
                                onChanged: (quality) =>
                                    setState(() => _videoQuality = quality!),
                                child: Text(_videoQuality.name),
                              ),
                            ],
                          ),
                          Divider(
                              color: MacosColors.systemGrayColor
                                  .withValues(alpha: .2)),
                          Row(
                            children: [
                              const Text('Video format'),
                              const Spacer(),
                              NativeDropdownButton(
                                value: _videoFormat,
                                items: VideoFormat.values
                                    .map((format) =>
                                        NativeDropdownItem<VideoFormat>(
                                            value: format, label: format.name))
                                    .toList(),
                                onChanged: (format) =>
                                    setState(() => _videoFormat = format!),
                                child: Text(_videoFormat.name),
                              ),
                            ],
                          ),
                          Divider(
                              color: MacosColors.systemGrayColor
                                  .withValues(alpha: .2)),
                          Row(
                            children: [
                              const Text('Video size'),
                              const Spacer(),
                              NativeDropdownButton(
                                value: _videoDownscale,
                                items: VideoDownscale.values
                                    .map((scale) =>
                                        NativeDropdownItem<VideoDownscale>(
                                            value: scale, label: scale.name))
                                    .toList(),
                                onChanged: (scale) =>
                                    setState(() => _videoDownscale = scale!),
                                child: Text(_videoDownscale.name),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (selectedItems().containsImage)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: MacosColors.systemGrayColor
                                .withValues(alpha: .2)),
                        borderRadius: BorderRadius.circular(6),
                        color: MacosColors.controlColor
                            .resolvedColor(context)
                            .withValues(alpha: .03),
                      ),
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('Image quality'),
                              const Spacer(),
                              NativeDropdownButton(
                                value: _imageQuality,
                                items: ImageQuality.values
                                    .map((quality) =>
                                        NativeDropdownItem<ImageQuality>(
                                            value: quality,
                                            label: quality.name))
                                    .toList(),
                                onChanged: (quality) =>
                                    setState(() => _imageQuality = quality!),
                                child: Text(_imageQuality.name),
                              ),
                            ],
                          ),
                          Divider(
                              color: MacosColors.systemGrayColor
                                  .withValues(alpha: .2)),
                          Row(
                            children: [
                              const Text('Image format'),
                              const Spacer(),
                              NativeDropdownButton(
                                value: _imageFormat,
                                items: ImageFormat.values
                                    .map((format) =>
                                        NativeDropdownItem<ImageFormat>(
                                            value: format, label: format.name))
                                    .toList(),
                                onChanged: (format) =>
                                    setState(() => _imageFormat = format!),
                                child: Text(_imageFormat.name),
                              ),
                            ],
                          ),
                          Divider(
                              color: MacosColors.systemGrayColor
                                  .withValues(alpha: .2)),
                          Row(
                            children: [
                              const Text('Image size'),
                              const Spacer(),
                              NativeDropdownButton(
                                value: _imageDownscale,
                                items: ImageDownscale.values
                                    .map((scale) =>
                                        NativeDropdownItem<ImageDownscale>(
                                            value: scale, label: scale.name))
                                    .toList(),
                                onChanged: (scale) =>
                                    setState(() => _imageDownscale = scale!),
                                child: Text(_imageDownscale.name),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: MacosColors.systemGrayColor
                              .withValues(alpha: .2)),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                        bottom: Radius.circular(24),
                      ),
                      color: MacosColors.controlColor
                          .resolvedColor(context)
                          .withValues(alpha: .03),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          height: 40,
                          child: minifyInProgress()
                              ? Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ProgressBar(
                                        value: ((processedFiles() +
                                                    minifyOneFileProgress()) /
                                                totalFiles() *
                                                100)
                                            .clamp(0, 100),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Processing: ${processedFiles()} / ${totalFiles()}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        GlassButton(
                                          secondary: true,
                                          onTap: cancelMinification,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 8),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : GlassButton(
                                  radius: 16,
                                  onTap: disabled
                                      ? null
                                      : () async {
                                          // await cli.setup(
                                          //   onProgress: (step, progress) {
                                          //     logger.log(
                                          //         '[Cli.setup] $step: ${(progress * 100).toStringAsFixed(1)}%');
                                          //   },
                                          //   onError: (error) {
                                          //     logger.log('[Cli.setup] $error');
                                          //   },
                                          //   onSuccess: () async {
                                          //     logger
                                          //         .log('[Cli.setup] Setup completed');

                                          //     await logger
                                          //         .log('Minify button pressed');
                                          //     if (items().isEmpty) {
                                          //       await logger.log(
                                          //           'Minify button pressed but items list is empty');
                                          //       await logger.log(
                                          //           'Action aborted - no files to process');
                                          //       return;
                                          //     }
                                          //     await logger.log(
                                          //         'Minify button pressed with ${items().length} items');
                                          //     await logger.log('Files breakdown:');
                                          //     await logger.log(
                                          //         '- Video files: ${items().videoPaths.length}');
                                          //     await logger.log(
                                          //         '- Image files: ${items().imagePaths.length}');
                                          //     await logger.log('Selected settings:');
                                          //     await logger.log(
                                          //         '- Video quality: ${_videoQuality.name}');
                                          //     await logger.log(
                                          //         '- Video format: ${_videoFormat.name}');
                                          //     await logger.log(
                                          //         '- Image quality: ${_imageQuality.name}');
                                          //     await logger.log(
                                          //         '- Image format: ${_imageFormat.name}');
                                          //     await logger.log(
                                          //         'Starting minification process...');
                                          //     minifyFiles();
                                          //   },
                                          // );
                                          // return;

                                          await logger
                                              .log('Minify button pressed');
                                          if (items().isEmpty) {
                                            await logger.log(
                                                'Minify button pressed but items list is empty');
                                            await logger.log(
                                                'Action aborted - no files to process');
                                            return;
                                          }
                                          await logger.log(
                                              'Minify button pressed with ${items().length} items');
                                          await logger.log('Files breakdown:');
                                          await logger.log(
                                              '- Video files: ${items().videoPaths.length}');
                                          await logger.log(
                                              '- Image files: ${items().imagePaths.length}');
                                          await logger
                                              .log('Selected settings:');
                                          await logger.log(
                                              '- Video quality: ${_videoQuality.name}');
                                          await logger.log(
                                              '- Video format: ${_videoFormat.name}');
                                          await logger.log(
                                              '- Image quality: ${_imageQuality.name}');
                                          await logger.log(
                                              '- Image format: ${_imageFormat.name}');
                                          await logger.log(
                                              'Starting minification process...');
                                          minifyFiles();
                                        },
                                  child: const Text('Compress',
                                      style: TextStyle(fontSize: 14)),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        });
  }

  void cancelMinification() async {
    await logger.log('Cancelling minification process...');
    cli.cancel();
    await logger.log('CLI process cancelled');
    processedFiles.value = 0;
    await logger.log('Reset processed files count to 0');
    minifyInProgress.value = false;
    await logger.log('Set minification progress status to false');
    minifyOneFileProgress.value = 0;
    await logger.log('Reset single file progress to 0');
    totalFiles.value = 0;
    await logger.log('Reset total files count to 0');
    await logger.log('Minification cancellation completed');
  }

  void minifyFiles() async {
    await logger.log('Starting minification process for all files');
    processedFiles.value = 0;
    await logger.log('Reset processed files counter to 0');
    final videoPaths = items().videoPaths;
    await logger.log('Retrieved video paths, count: ${videoPaths.length}');
    final imagePaths = items().imagePaths;
    await logger.log('Retrieved image paths, count: ${imagePaths.length}');
    totalFiles.value = videoPaths.length + imagePaths.length;
    await logger.log('Set total files count to: ${totalFiles.value}');
    minifyInProgress.value = true;
    await logger.log('Set minification in progress status to true');

    await logger.log('Starting image processing...');
    for (var path in imagePaths) {
      await logger.log('Processing image: $path');
      minifyOneFileProgress.value = 0;
      await logger.log('Reset progress for current image');
      await minifyImage(path);
      processedFiles.value++;
      logger
          .log('Incremented processed files count to: ${processedFiles.value}');
    }

    await logger.log('Starting video processing...');
    for (var path in videoPaths) {
      await logger.log('Processing video: $path');
      minifyOneFileProgress.value = 0;
      await logger.log('Reset progress for current video');
      await minifyVideo(
        path,
        quality: _videoQuality.name,
        format:
            _videoFormat == VideoFormat.sameAsInput ? null : _videoFormat.name,
        downScale: _videoDownscale.value, // Add this
      );
      processedFiles.value++;
      logger
          .log('Incremented processed files count to: ${processedFiles.value}');
    }

    await logger.log('All files processed, waiting for final delay...');
    await Future.delayed(const Duration(milliseconds: 800));
    processedFiles.value = totalFiles.value;
    await logger
        .log('Updated processed files to match total: ${totalFiles.value}');
    await Future.delayed(const Duration(milliseconds: 500));
    minifyInProgress.value = false;
    await logger.log('Minification process completed successfully');
  }

  Future<void> minifyVideo(String filePath,
      {required String quality, String? format, required int downScale}) async {
    await logger.log('Starting minification for video: $filePath');
    final stopwatch = Stopwatch()..start();
    await logger.log('Started stopwatch for timing');
    try {
      await logger.log('Output path set to: $filePath');
      await logger.log('Checking for ffprobe availability...');

      final whichResult = await cli.run('which', ['ffprobe']);
      await logger.log(
          'which ffprobe command executed with exit code: ${whichResult.exitCode}');

      if (whichResult.exitCode != 0) {
        await logger.log('ffprobe not found in PATH');
        throw Exception(
            'ffprobe not found in PATH. Please ensure FFmpeg is installed.');
      }

      final ffprobePath = (whichResult.stdout as String).trim();
      await logger.log('Found ffprobe at path: $ffprobePath');

      await logger.log('Executing ffprobe to get video duration...');
      final probeResult = await cli.run(ffprobePath, [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        filePath
      ]);
      await logger.log(
          'ffprobe command completed with exit code: ${probeResult.exitCode}');

      if (probeResult.exitCode != 0) {
        await logger.log('Error in ffprobe execution: ${probeResult.stderr}');
        throw Exception('Error getting video duration: ${probeResult.stderr}');
      }

      final duration = double.parse((probeResult.stdout as String).trim());
      await logger.log(
          'Video duration retrieved: ${duration.toStringAsFixed(2)} seconds');

      await logger.log(
          'Starting video minification with quality: ${_videoQuality.name}');

      // Enable hardware acceleration for VP9 if available
      const bool tryHardwareAcceleration = true;

      final minifiedPath = await cli.minifyVideo(
        filePath,
        quality: _videoQuality.name,
        format:
            _videoFormat == VideoFormat.sameAsInput ? null : _videoFormat.name,
        enableHardwareAcceleration: tryHardwareAcceleration,
        downScale: _videoDownscale.value, // Add this
        onProgress: (progress) async {
          minifyOneFileProgress.value = progress;
          await logger.log(
              'Video minification progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
      );

      if (minifiedPath == null) {
        await logger.log('Minification failed, no output path returned');
        throw Exception('Minification failed, no output path returned');
      }

      final originalSize = File(filePath).lengthSync();
      await logger.log('Original file size: $originalSize bytes');
      final minifiedSize = File(minifiedPath).lengthSync();
      await logger.log('Minified file size: $minifiedSize bytes');

      final minifiedFile = MinifiedFile(
        originalPath: filePath,
        minifiedPath: minifiedPath,
        originalSize: originalSize,
        minifiedSize: minifiedSize,
        duration: stopwatch.elapsed,
      );
      await logger.log(
          'Created MinifiedFile object with duration: ${stopwatch.elapsed}');

      minifiedFiles.value = [...minifiedFiles(), minifiedFile];
      await logger.log('Added minified file to tracking list');

      // Update or add minified path to items set
      final newItems = items().toList();
      final index = newItems.indexWhere((item) => item == filePath);
      if (index != -1) {
        newItems[index] = minifiedPath;
      } else {
        newItems.add(minifiedPath);
      }
      items.value = newItems.toSet();
      await logger.log('Updated items set with minified path');

      final compressionRatio = (1 - (minifiedSize / originalSize)) * 100;
      await logger.log(
          'Achieved compression ratio: ${compressionRatio.toStringAsFixed(2)}%');
    } catch (e) {
      await logger.log('Error occurred during video minification: $e');
      errorMessages.value = [
        ...errorMessages(),
        'Failed to minify $filePath: $e'
      ];
      await logger.log('Added error message to error messages list');
    }
    stopwatch.stop();
    await logger.log('Video minification process completed for: $filePath');
  }

  Future<void> minifyImage(String filePath) async {
    await logger.log('Starting minification for image: $filePath');
    final stopwatch = Stopwatch()..start();
    await logger.log('Started stopwatch for timing');

    try {
      await logger.log(
          'Beginning image minification with quality: ${_imageQuality.value}');
      cli;
      await logger.log('Output path set to: $filePath');
      await logger.log(
          'Format setting: ${_imageFormat == ImageFormat.sameAsInput ? 'same as input' : _imageFormat.name}');
      onProgress(progress) async {
        minifyOneFileProgress.value = progress;
        await logger.log(
            'Image minification progress: ${(progress * 100).toStringAsFixed(2)}%');
      }

      await logger.log('Set progress');

      final minifiedPath = await cli.minifyImage(
        filePath,
        fileExtension:
            _imageFormat == ImageFormat.sameAsInput ? null : _imageFormat.name,
        quality: _imageQuality.value,
        downScale: _imageDownscale.value, // Add this line
        onProgress: onProgress,
      );

      if (minifiedPath == null) {
        await logger.log('Minification failed, no output path returned');
        throw Exception('Minification failed, no output path returned');
      }

      final originalSize = File(filePath).lengthSync();
      await logger.log('Original image size: $originalSize bytes');
      final minifiedSize = File(minifiedPath).lengthSync();
      await logger.log('Minified image size: $minifiedSize bytes');

      final minifiedFile = MinifiedFile(
        originalPath: filePath,
        minifiedPath: minifiedPath,
        originalSize: originalSize,
        minifiedSize: minifiedSize,
        duration: stopwatch.elapsed,
      );
      await logger.log(
          'Created MinifiedFile object with duration: ${stopwatch.elapsed}');

      minifiedFiles.value = [...minifiedFiles(), minifiedFile];
      await logger.log('Added minified image to tracking list');

      // Update or add minified path to items set
      final newItems = items().toList();
      final index = newItems.indexWhere((item) => item == filePath);
      if (index != -1) {
        newItems[index] = minifiedPath;
      } else {
        newItems.add(minifiedPath);
      }
      items.value = newItems.toSet();
      await logger.log('Updated items set with minified path');

      final compressionRatio = (1 - (minifiedSize / originalSize)) * 100;
      await logger.log(
          'Achieved compression ratio: ${compressionRatio.toStringAsFixed(2)}%');
    } catch (e) {
      await logger.log('Error occurred during image minification: $e');
      errorMessages.value = [
        ...errorMessages(),
        'Failed to minify $filePath: $e'
      ];
      await logger.log('Added error message to error messages list');
    }
    stopwatch.stop();
    await logger.log('Image minification process completed for: $filePath');
  }
}
