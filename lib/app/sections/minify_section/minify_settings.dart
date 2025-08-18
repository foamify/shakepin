import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:shakepin/widgets/cli_aware_button.dart';
import 'package:shakepin/widgets/native_dropdown_button.dart';

class MinifySettings extends StatefulWidget {
  const MinifySettings({super.key});

  @override
  State<MinifySettings> createState() => _MinifySettingsState();
}

class _MinifySettingsState extends State<MinifySettings> {
  var _videoQuality = VideoQuality.goodQuality;
  var _videoFormat = VideoFormat.sameAsInput;
  var _videoDownscale = VideoDownscale.sameAsInput;
  var _imageQuality = ImageQuality.normal;
  var _imageFormat = ImageFormat.sameAsInput;
  var _imageDownscale = ImageDownscale.sameAsInput;
  var _gifQuality = GifQuality.high;
  var _gifFps = 24;
  var initialGifFpsGestureValue = 0.0;
  var initialDy = 0.0;
  final _gifFpsController = TextEditingController();
  
  // Store listener reference for proper disposal
  late VoidCallback _retryListener;

  // Add crop state variables
  final _leftCrop = ValueNotifier<int>(0);
  final _rightCrop = ValueNotifier<int>(0);
  final _topCrop = ValueNotifier<int>(0);
  final _bottomCrop = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _gifFpsController.text = _gifFps.toString();
    selectedItems.addListener(() => setState(() {}));
    
    // Listen for retry trigger
    _retryListener = () {
      if (retryTrigger.value == 'minify') {
        retryTrigger.value = null; // Reset trigger
        minifyFiles(); // Retry the minification
      }
    };
    retryTrigger.addListener(_retryListener);
  }

  @override
  void dispose() {
    _gifFpsController.dispose();
    _leftCrop.dispose();
    _rightCrop.dispose();
    _topCrop.dispose();
    _bottomCrop.dispose();
    retryTrigger.removeListener(_retryListener); // Clean up retry listener
    super.dispose();
  }

  bool get disabled =>
      !selectedItems().containsImage && !selectedItems().containsVideo;

  List<String> _getRequiredTools() {
    final tools = <String>{};
    
    // Check if we have video files that need ffmpeg
    if (items().videoPaths.isNotEmpty) {
      tools.add('ffmpeg');
    }
    
    // Check if we have image files that need imagemagick
    if (items().imagePaths.isNotEmpty) {
      tools.add('imagemagick');
    }
    
    return tools.toList();
  }

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
                          if (_videoFormat != VideoFormat.gif) ...[
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
                          ],
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
                          if (_videoFormat == VideoFormat.gif) ...[
                            Divider(
                                color: MacosColors.systemGrayColor
                                    .withValues(alpha: .2)),
                            Row(
                              children: [
                                const Text('GIF quality'),
                                const Spacer(),
                                NativeDropdownButton(
                                  value: _gifQuality,
                                  items: GifQuality.values
                                      .map((quality) =>
                                          NativeDropdownItem<GifQuality>(
                                              value: quality,
                                              label: quality.name))
                                      .toList(),
                                  onChanged: (quality) =>
                                      setState(() => _gifQuality = quality!),
                                  child: Text(_gifQuality.name),
                                ),
                              ],
                            ),
                            Divider(
                                color: MacosColors.systemGrayColor
                                    .withValues(alpha: .2)),
                            GestureDetector(
                              onPanDown: (details) {
                                initialGifFpsGestureValue = _gifFps.toDouble();
                                initialDy = details.globalPosition.dy;
                              },
                              onPanUpdate: (details) {
                                final dy =
                                    -(details.globalPosition.dy - initialDy) *
                                        60 /
                                        400;

                                final fps = (initialGifFpsGestureValue + dy)
                                    .clamp(1, 60);

                                if (initialGifFpsGestureValue + dy > 60 ||
                                    _gifFps + dy < 1) {
                                  initialGifFpsGestureValue =
                                      _gifFps.toDouble();
                                  initialDy = details.globalPosition.dy;
                                }

                                if (fps != _gifFps) {
                                  setState(() {
                                    _gifFps = fps.round();
                                    _gifFpsController.text =
                                        fps.round().toString();
                                  });
                                }
                              },
                              child: Row(
                                children: [
                                  const Text('GIF framerate'),
                                  const Spacer(),
                                  IntrinsicWidth(
                                    child: MacosTextField(
                                      placeholder: '60',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      maxLength: 2,
                                      controller: _gifFpsController,
                                      onChanged: (value) {
                                        final fps = int.tryParse(value);
                                        if (fps != null &&
                                            fps >= 1 &&
                                            fps <= 60) {
                                          setState(() => _gifFps = fps);
                                        } else {
                                          _gifFpsController.text =
                                              _gifFps.toString();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('FPS',
                                      style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
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
                  // Add new crop container here
                  if (selectedItems().containsImage ||
                      selectedItems().containsVideo)
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
                      child: Row(
                        children: [
                          const Text('Crop Media'),
                          const Spacer(),
                          SizedBox(
                            width: 112,
                            child: GlassButton(
                              radius: 6,
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              onTap: () {
                                isCropApp.value = true;
                                showApp();
                              },
                              child: const Text('Open Cropper'),
                            ),
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
                              : CliAwareButton(
                                  requiredTools: _getRequiredTools(),
                                  radius: 16,
                                  disabled: disabled,
                                  onTap: () async {
                                    await logger.log('Minify button pressed');
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
                                    await logger.log('Selected settings:');
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

      if (_videoFormat == VideoFormat.gif) {
        await cli.convertToGif(
          path,
          quality: _gifQuality.value,
          fps: _gifFps,
          onProgress: (progress) {
            minifyOneFileProgress.value = progress;
          },
          downScale: _videoDownscale.value,
        );
      } else {
        await minifyVideo(
          path,
          quality: _videoQuality.name,
          format: _videoFormat == VideoFormat.sameAsInput
              ? null
              : _videoFormat.name,
          downScale: _videoDownscale.value,
        );
      }

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

      final isFFprobeAvailable = await cli.isFFprobeAvailable();
      await logger.log('FFprobe availability check result: $isFFprobeAvailable');

      if (!isFFprobeAvailable) {
        await logger.log('ffprobe not found in PATH');
        throw Exception(
            'FFmpeg is not installed or not found in PATH. Please install FFmpeg to compress videos.');
      }

      await logger.log('FFprobe is available, proceeding with video processing');

      await logger.log('Executing ffprobe to get video duration...');
      final probeResult = await cli.run('ffprobe', [
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

      // Get crop values if they exist
      final cropValues = cropData()[filePath];
      final cropLeft = cropValues?.left ?? 0;
      final cropRight = cropValues?.right ?? 0;
      final cropTop = cropValues?.top ?? 0;
      final cropBottom = cropValues?.bottom ?? 0;

      await logger.log(
          'Crop values - L:$cropLeft R:$cropRight T:$cropTop B:$cropBottom');

      final minifiedPath = await cli.minifyVideo(
        filePath,
        quality: _videoQuality.name,
        format:
            _videoFormat == VideoFormat.sameAsInput ? null : _videoFormat.name,
        enableHardwareAcceleration: tryHardwareAcceleration,
        downScale: _videoDownscale.value,
        cropLeft: cropLeft,
        cropRight: cropRight,
        cropTop: cropTop,
        cropBottom: cropBottom,
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

      onProgress(progress) async {
        minifyOneFileProgress.value = progress;
        await logger.log(
            'Image minification progress: ${(progress * 100).toStringAsFixed(2)}%');
      }

      // Get crop values if they exist
      final cropValues = cropData()[filePath];
      final cropLeft = cropValues?.left ?? 0;
      final cropRight = cropValues?.right ?? 0;
      final cropTop = cropValues?.top ?? 0;
      final cropBottom = cropValues?.bottom ?? 0;

      await logger.log(
          'Crop values - L:$cropLeft R:$cropRight T:$cropTop B:$cropBottom');

      final minifiedPath = await cli.minifyImage(
        filePath,
        fileExtension:
            _imageFormat == ImageFormat.sameAsInput ? null : _imageFormat.name,
        quality: _imageQuality.value,
        downScale: _imageDownscale.value,
        onProgress: onProgress,
        cropLeft: cropLeft,
        cropRight: cropRight,
        cropTop: cropTop,
        cropBottom: cropBottom,
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
