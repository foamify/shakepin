import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/app/main_drop/minify_section/minify_state.dart';
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
  var _imageQuality = ImageQuality.normal;
  var _imageFormat = ImageFormat.sameAsInput;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge([
          items,
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
                  if (items().containsVideo)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: MacosColors.systemGrayColor.withOpacity(.2)),
                        borderRadius: BorderRadius.circular(6),
                        color: MacosColors.controlColor
                            .resolvedColor(context)
                            .withOpacity(.03),
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
                          const Divider(color: MacosColors.gridColor),
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
                        ],
                      ),
                    ),
                  if (items().containsImage)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: MacosColors.systemGrayColor.withOpacity(.2)),
                        borderRadius: BorderRadius.circular(6),
                        color: MacosColors.controlColor
                            .resolvedColor(context)
                            .withOpacity(.03),
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
                          const Divider(color: MacosColors.gridColor),
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
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: MacosColors.systemGrayColor.withOpacity(.2)),
                      borderRadius: BorderRadius.circular(6),
                      color: MacosColors.controlColor
                          .resolvedColor(context)
                          .withOpacity(.03),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
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
                                  radius: 12,
                                  onTap: items().isEmpty ? null : minifyFiles,
                                  child: const Text('Minify',
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

  void cancelMinification() {
    cli.cancel();
    processedFiles.value = 0;
    minifyInProgress.value = false;
    minifyOneFileProgress.value = 0;
    totalFiles.value = 0;
  }

  void minifyFiles() async {
    processedFiles.value = 0;
    final videoPaths = items().videoPaths;
    final imagePaths = items().imagePaths;
    totalFiles.value = videoPaths.length + imagePaths.length;
    minifyInProgress.value = true;
    for (var path in imagePaths) {
      minifyOneFileProgress.value = 0;
      await minifyImage(path);
      processedFiles.value++;
    }
    for (var path in videoPaths) {
      minifyOneFileProgress.value = 0;
      await minifyVideo(path);
      processedFiles.value++;
    }
    await Future.delayed(const Duration(milliseconds: 800));
    processedFiles.value = totalFiles.value;
    await Future.delayed(const Duration(milliseconds: 500));
    minifyInProgress.value = false;
  }

  Future<void> minifyVideo(String outputPath) async {
    debugPrint('Starting minification for video: $outputPath');
    final stopwatch = Stopwatch()..start();
    try {
      debugPrint('Output path set to: $outputPath');

      // Use which command to find ffprobe path
      final whichResult = await Process.run('which', ['ffprobe']);
      if (whichResult.exitCode != 0) {
        throw Exception(
            'ffprobe not found in PATH. Please ensure FFmpeg is installed.');
      }
      final ffprobePath = (whichResult.stdout as String).trim();

      debugPrint('Fetching video duration...');
      final probeResult = await Process.run(ffprobePath, [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        outputPath
      ]);

      if (probeResult.exitCode != 0) {
        throw Exception('Error getting video duration: ${probeResult.stderr}');
      }

      final duration = double.parse((probeResult.stdout as String).trim());
      debugPrint('Video duration: ${duration.toStringAsFixed(2)} seconds');

      debugPrint('Starting video minification process...');
      await cli.minifyVideo(
        outputPath,
        outputPath,
        quality: _videoQuality.name,
        format: _videoFormat == VideoFormat.sameAsInput ? null : _videoFormat.name,
        onProgress: (progress) {
          minifyOneFileProgress.value = progress;
          // debugPrint(
          //     'Minification progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
      );

      final originalSize = File(outputPath).lengthSync();
      final minifiedSize = File(outputPath).lengthSync();
      debugPrint('Original size: $originalSize bytes');
      debugPrint('Minified size: $minifiedSize bytes');

      final minifiedFile = MinifiedFile(
        originalPath: outputPath,
        minifiedPath: outputPath,
        originalSize: originalSize,
        minifiedSize: minifiedSize,
        duration: stopwatch.elapsed,
      );
      minifiedFiles.value = [...minifiedFiles(), minifiedFile];
      debugPrint('Minified file added to the list');

      final compressionRatio = (1 - (minifiedSize / originalSize)) * 100;
      debugPrint('Compression ratio: ${compressionRatio.toStringAsFixed(2)}%');
    } catch (e) {
      debugPrint('Error occurred during minification: $e');
      errorMessages.value = [
        ...errorMessages(),
        'Failed to minify $outputPath: $e'
      ];
    }
    stopwatch.stop();
    debugPrint('Minification process completed for: $outputPath');
  }

  Future<void> minifyImage(String outputPath) async {
    debugPrint('Starting minification for image: $outputPath');
    final stopwatch = Stopwatch()..start();
    try {
      debugPrint('Output path set to: $outputPath');

      await cli.minifyImage(
        outputPath,
        outputPath,
        quality: _imageQuality.value,
        onProgress: (progress) {
          minifyOneFileProgress.value = progress;
          // debugPrint(
          //     'Minification progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
      );

      final originalSize = File(outputPath).lengthSync();
      final minifiedSize = File(outputPath).lengthSync();
      debugPrint('Original size: $originalSize bytes');
      debugPrint('Minified size: $minifiedSize bytes');

      final minifiedFile = MinifiedFile(
        originalPath: outputPath,
        minifiedPath: outputPath,
        originalSize: originalSize,
        minifiedSize: minifiedSize,
        duration: stopwatch.elapsed,
      );
      minifiedFiles.value = [...minifiedFiles(), minifiedFile];
      debugPrint('Minified file added to the list');

      final compressionRatio = (1 - (minifiedSize / originalSize)) * 100;
      debugPrint('Compression ratio: ${compressionRatio.toStringAsFixed(2)}%');
    } catch (e) {
      debugPrint('Error occurred during image minification: $e');
      errorMessages.value = [
        ...errorMessages(),
        'Failed to minify $outputPath: $e'
      ];
    }
    stopwatch.stop();
    debugPrint('Minification process completed for: $outputPath');
  }
}
