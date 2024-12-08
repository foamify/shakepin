import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/state.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:io';
import 'package:libcaesium_dart/libcaesium_dart.dart';

import '../utils/utils.dart';
import '../widgets/drop_target.dart';

// Common enums
enum ImageQuality {
  lowest,
  low,
  normal,
  high,
  highest;

  String get name => switch (this) {
        ImageQuality.lowest => 'Lowest',
        ImageQuality.low => 'Low',
        ImageQuality.normal => 'Normal',
        ImageQuality.high => 'High',
        ImageQuality.highest => 'Highest',
      };
}

enum VideoQuality {
  lowestQuality,
  lowQuality,
  mediumQuality,
  goodQuality,
  highQuality,
  veryHighQuality,
  highestQuality,
  lossless;

  String get name => switch (this) {
        VideoQuality.lowestQuality => 'Lowest quality',
        VideoQuality.lowQuality => 'Low quality',
        VideoQuality.mediumQuality => 'Medium quality',
        VideoQuality.goodQuality => 'Good quality',
        VideoQuality.highQuality => 'High quality',
        VideoQuality.veryHighQuality => 'Very high quality',
        VideoQuality.highestQuality => 'Highest quality',
        VideoQuality.lossless => 'Lossless',
      };
}

enum VideoFormat {
  webm,
  mp4,
  gif,
  sameAsInput;

  String get name => switch (this) {
        VideoFormat.webm => 'WebM',
        VideoFormat.mp4 => 'MP4',
        VideoFormat.gif => 'GIF',
        VideoFormat.sameAsInput => 'Same as input',
      };
}

enum ImageFormat {
  sameAsInput,
  png,
  jpg,
  webp,
  tiff;

  String get name => switch (this) {
        ImageFormat.sameAsInput => 'Same as input',
        ImageFormat.png => 'PNG',
        ImageFormat.jpg => 'JPG',
        ImageFormat.webp => 'WEBP',
        ImageFormat.tiff => 'TIFF',
      };
}

class MinifiedFile {
  final String originalPath;
  final String minifiedPath;
  final int originalSize;
  final int minifiedSize;
  final Duration duration;

  MinifiedFile({
    required this.originalPath,
    required this.minifiedPath,
    required this.originalSize,
    required this.minifiedSize,
    required this.duration,
  });

  double get savingsPercentage =>
      (originalSize - minifiedSize) / originalSize * 100;

  String get originalFileName => path.basename(originalPath);
  String get minifiedFileName => path.basename(minifiedPath);
}

Future<MinifiedFile?> minifyImageWithCaesium(
    String filePath, String outputPath, ImageQuality quality,
    {bool removeInputFile = false}) async {
  final file = File(filePath);

  try {
    debugPrint('Starting image compression');
    await compress(
      inputPath: filePath,
      outputPath: outputPath,
      quality: switch (quality) {
        ImageQuality.lowest => 30,
        ImageQuality.low => 50,
        ImageQuality.normal => 80,
        ImageQuality.high => 90,
        ImageQuality.highest => 95,
      },
      pngOptimizationLevel: 3,
      keepMetadata: true,
      optimize: false,
    );
    debugPrint('Compression completed');

    final originalSize = file.lengthSync();
    debugPrint('Original size: $originalSize bytes');
    final minifiedSize = File(outputPath).lengthSync();
    debugPrint('Minified size: $minifiedSize bytes');

    if (removeInputFile) {
      debugPrint('Removing input file');
      await file.delete();
    }

    debugPrint('Creating MinifiedFile object');
    return MinifiedFile(
      originalPath: filePath,
      minifiedPath: outputPath,
      originalSize: originalSize,
      minifiedSize: minifiedSize,
      duration: const Duration(),
    );
  } catch (e) {
    print('Error minifying image: $e');
    return null;
  }
}

class FileHoverWidget extends StatefulWidget {
  const FileHoverWidget({
    super.key,
    required this.icon,
    required this.fileName,
    required this.fileSize,
  });

  final IconData icon;
  final String fileName;
  final String fileSize;

  @override
  State<FileHoverWidget> createState() => _FileHoverWidgetState();
}

class _FileHoverWidgetState extends State<FileHoverWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: Durations.short2,
        color: _isHovered
            ? CupertinoColors.systemGrey6.withOpacity(.2)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Icon(widget.icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.fileName,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.fileSize,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget buildMinifiedFilesList(
    List<MinifiedFile> allProcessedFiles, ScrollController scrollController) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(
            color: CupertinoColors.systemGrey.withOpacity(.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: MacosScrollbar(
          controller: scrollController,
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: allProcessedFiles.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: CupertinoColors.systemGrey.withOpacity(.2),
            ),
            itemBuilder: (context, index) {
              final file = allProcessedFiles[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(file.minifiedFileName,
                              style: const TextStyle(fontSize: 12)),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${formatFileSize(file.originalSize)} → ${formatFileSize(file.minifiedSize)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                                const TextSpan(text: ' • '),
                                TextSpan(
                                  text: file.savingsPercentage >= 0
                                      ? '${file.savingsPercentage.toStringAsFixed(1)}% saved'
                                      : '${(-file.savingsPercentage).toStringAsFixed(1)}% increased',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: file.savingsPercentage > 10
                                        ? Colors.green
                                        : file.savingsPercentage > 5
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Duration: ${file.duration.inSeconds}.${file.duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0')}s',
                            style: const TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PushButton(
                      controlSize: ControlSize.regular,
                      onPressed: () {
                        Process.run('open', ['-R', file.minifiedPath]);
                      },
                      child: const Text('Show in Finder'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

Widget buildFileList(
    ValueNotifier<Set<String>> files,
    ValueNotifier<bool> isDragging,
    ScrollController fileScrollController,
    Function(String) removeFile) {
  return ListenableBuilder(
      listenable: Listenable.merge([files, isDragging]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropTarget(
              label: 'minify-drop',
              onDragEnter: (position) {
                haptic.levelChange();
                isDragging.value = true;
              },
              onDragExited: () {
                isDragging.value = false;
              },
              onDragPerform: (paths) {
                isDragging.value = false;
                files.addAll(paths.where(isSupportedFile).toSet());
              },
              onDragConclude: () {},
              child: AnimatedContainer(
                duration: Durations.medium2,
                height: 200,
                foregroundDecoration: BoxDecoration(
                  border: isDragging()
                      ? Border.all(
                          color: CupertinoColors.systemBlue,
                          width: 2,
                        )
                      : Border.all(
                          color: CupertinoColors.systemGrey.withOpacity(.3),
                        ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: files().isEmpty
                    ? const Center(
                        child: Text(
                          'Drop files here',
                          style: TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 24,
                            child: Center(
                              child: Text(
                                '${files().length} Files',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: CupertinoColors.systemGrey.withOpacity(.2),
                          ),
                          Expanded(
                            child: MacosScrollbar(
                              controller: fileScrollController,
                              child: ListView.separated(
                                controller: fileScrollController,
                                itemCount: files().length,
                                separatorBuilder: (context, index) => Divider(
                                  indent: 12,
                                  endIndent: 12,
                                  height: 1,
                                  color: CupertinoColors.systemGrey
                                      .withOpacity(.2),
                                ),
                                itemBuilder: (context, index) {
                                  final filePath = files().elementAt(index);
                                  final file = File(filePath);
                                  final fileName = path.basename(filePath);
                                  final fileSize =
                                      formatFileSize(file.lengthSync());
                                  final isImage = isImageFile(fileName);
                                  final icon = isImage
                                      ? FluentIcons.image_24_regular
                                      : FluentIcons.video_24_regular;
                                  return ContextMenuWidget(
                                    menuProvider: (request) => Menu(
                                      children: [
                                        MenuAction(
                                          callback: () {
                                            Process.run(
                                                'open', ['-R', filePath]);
                                          },
                                          title: 'Show in Finder',
                                        ),
                                        MenuAction(
                                          callback: () {
                                            removeFile(filePath);
                                          },
                                          title: 'Remove',
                                        ),
                                      ],
                                    ),
                                    child: FileHoverWidget(
                                      icon: icon,
                                      fileName: fileName,
                                      fileSize: fileSize,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      });
}

String formatEnumName(String name) {
  return name
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .replaceAll('Webm', ' (WebM)')
      .replaceAll('Mp4', ' (MP4)')
      .capitalize();
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
