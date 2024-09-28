import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:super_context_menu/super_context_menu.dart';
import 'dart:async';
import 'package:libcaesium_dart/libcaesium_dart.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_session.dart';

import '../state.dart';
import '../utils/utils.dart';
import '../widgets/drop_target.dart';

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

class MinificationManager {
  final String imageQuality;
  final String videoQuality;
  final String videoFormat;
  FFmpegSession? currentSession;

  MinificationManager({
    required this.imageQuality,
    required this.videoQuality,
    required this.videoFormat,
  });

  Future<MinifiedFile?> minifyFile(
      String filePath, Directory downloadsDir) async {
    final stopwatch = Stopwatch()..start();
    MinifiedFile? result;

    if (isImageFile(filePath)) {
      result = await minifyImage(filePath, downloadsDir);
    } else if (isVideoFile(filePath)) {
      result = await minifyVideo(filePath, downloadsDir);
    }

    stopwatch.stop();

    if (result != null) {
      return MinifiedFile(
        originalPath: result.originalPath,
        minifiedPath: result.minifiedPath,
        originalSize: result.originalSize,
        minifiedSize: result.minifiedSize,
        duration: stopwatch.elapsed,
      );
    }

    return null;
  }

  Future<MinifiedFile?> minifyImage(
      String filePath, Directory downloadsDir) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileExtension = path.extension(fileName).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(fileName);

    var newFileName = '${fileNameWithoutExtension}_minified$fileExtension';
    var outputPath = path.join(downloadsDir.path, newFileName);

    // Check if the file already exists and generate a unique name if it does
    var counter = 1;
    while (File(outputPath).existsSync()) {
      newFileName =
          '${fileNameWithoutExtension}_minified_$counter$fileExtension';
      outputPath = path.join(downloadsDir.path, newFileName);
      counter++;
    }

    try {
      await compress(
        inputPath: filePath,
        outputPath: outputPath,
        quality: switch (imageQuality) {
          'Lowest' => 30,
          'Low' => 50,
          'Normal' => 80,
          'High' => 90,
          'Highest' => 95,
          _ => 80,
        },
        pngOptimizationLevel: 3,
        keepMetadata: true,
        optimize: false,
      );
      final originalSize = file.lengthSync();
      final minifiedSize = File(outputPath).lengthSync();

      // if (removeInputFiles) {
      //   await file.delete();
      // }

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

  Future<MinifiedFile?> minifyVideo(
      String filePath, Directory downloadsDir) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileNameWithoutExtension = path.basenameWithoutExtension(fileName);
    final fileExtension = path.extension(fileName).toLowerCase();

    var outputExtension = fileExtension;
    if (videoFormat != 'Same as input') {
      outputExtension = '.${videoFormat.toLowerCase()}';
    }

    var newFileName = '${fileNameWithoutExtension}_minified$outputExtension';
    var outputPath = path.join(downloadsDir.path, newFileName);

    // Check if the file already exists and generate a unique name if it does
    var counter = 1;
    while (File(outputPath).existsSync()) {
      newFileName =
          '${fileNameWithoutExtension}_minified_$counter$outputExtension';
      outputPath = path.join(path.dirname(filePath), newFileName);
      counter++;
    }

    final qualityArg = switch (videoQuality) {
      'Low' => '17',
      'Normal' => '23',
      'High' => '28',
      _ => '23', // Default to Normal
    };

    String command;
    if (videoFormat == 'WebM') {
      command =
          '-i "$filePath" -c:v vp9 -crf $qualityArg -b:v 1M -c:a opus -b:a 128k -strict -2 "$outputPath"';
    } else {
      command =
          '-i "$filePath" -c:v h264_videotoolbox -crf $qualityArg -preset medium -c:a aac -b:a 128k "$outputPath"';
    }

    try {
      currentSession = await FFmpegKit.execute(command);
      final returnCode = await currentSession!.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final originalSize = file.lengthSync();
        final minifiedSize = File(outputPath).lengthSync();

        return MinifiedFile(
          originalPath: filePath,
          minifiedPath: outputPath,
          originalSize: originalSize,
          minifiedSize: minifiedSize,
          duration: const Duration(),
        );
      } else {
        final logs = await currentSession!.getLogs();
        print(
            'Error minifying video: ${logs.map((e) => e.getMessage()).join('\n')}');
        return null;
      }
    } catch (e) {
      print('Error minifying video: $e');
      return null;
    }
  }

  void cancelMinification() {
    FFmpegKit.execute("-t 0");
    currentSession
        ?.cancel(); // this does not work https://github.com/arthenica/ffmpeg-kit/issues/1024
  }
}

class MinifyApp extends StatefulWidget {
  const MinifyApp({super.key});

  @override
  State<MinifyApp> createState() => _MinifyAppState();
}

class _MinifyAppState extends State<MinifyApp> {
  late final SharedPreferences prefs;
  final _minifileScrollController = ScrollController();
  final _fileScrollController = ScrollController();

  String videoQuality = 'Normal';
  String videoFormat = 'Same as input';
  String imageQuality = 'Normal';
  bool minifyInProgress = false;
  bool minifyFinished = false;
  int processedFiles = 0;
  int totalFiles = 0;
  List<MinifiedFile> minifiedFiles = [];
  List<MinifiedFile> allProcessedFiles = [];

  var files = <String>{};
  var isDragging = false;

  MinificationManager? _minificationManager;

  List<String> errorMessages = [];

  bool isSupportedFile(String filePath) {
    return isVideoFile(filePath) || isImageFile(filePath);
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      this.prefs = prefs;
    });

    dropChannel.setMinimumSize(AppSizes.minify);
    files = items().where(isSupportedFile).toSet();
  }

  Future<void> minifyFiles() async {
    setState(() {
      minifyInProgress = true;
      minifyFinished = false;
      processedFiles = 0;
      totalFiles = files.length;
      minifiedFiles.clear();
      errorMessages.clear();
    });

    _minificationManager = MinificationManager(
      imageQuality: imageQuality,
      videoQuality: videoQuality,
      videoFormat: videoFormat,
    );

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      setState(() {
        errorMessages.add(
            'Failed to get downloads directory.\nPlease make sure you have a Downloads folder in your home directory.');
      });
      return;
    }

    for (final filePath in files) {
      if (!minifyInProgress) break; // Check if cancellation was requested
      final minifiedFile =
          await _minificationManager!.minifyFile(filePath, downloadsDir);
      if (minifiedFile != null) {
        setState(() {
          minifiedFiles.add(minifiedFile);
          allProcessedFiles.add(minifiedFile);
          processedFiles++;
        });
      } else {
        setState(() {
          processedFiles++;
          errorMessages.add(
              'Failed to minify: ${path.basename(filePath)}'); // Add error message
        });
      }
    }

    setState(() {
      minifyInProgress = false;
      minifyFinished = true;
    });
  }

  void cancelMinification() {
    _minificationManager?.cancelMinification();
    setState(() {
      minifyInProgress = false;
    });
  }

  Widget _buildMinifiedFilesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color: CupertinoColors.systemGrey.withOpacity(.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: MacosScrollbar(
            controller: _minifileScrollController,
            child: ListView.separated(
              controller: _minifileScrollController,
              padding: const EdgeInsets.all(8),
              itemCount: allProcessedFiles
                  .length, // Use allProcessedFiles instead of minifiedFiles
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: CupertinoColors.systemGrey.withOpacity(.2),
              ),
              itemBuilder: (context, index) {
                final file = allProcessedFiles[index]; // Use allProcessedFiles
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
                            Text(
                              'Original: ${formatFileSize(file.originalSize)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            Text(
                              'Processed: ${formatFileSize(file.minifiedSize)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            Text(
                              file.savingsPercentage >= 0
                                  ? '${file.savingsPercentage.toStringAsFixed(1)}% saved'
                                  : '${(-file.savingsPercentage).toStringAsFixed(1)}% increased',
                              style: TextStyle(
                                fontSize: 10,
                                color: file.savingsPercentage > 10
                                    ? Colors.green
                                    : file.savingsPercentage > 5
                                        ? Colors.orange
                                        : file.savingsPercentage >= 0
                                            ? Colors.red
                                            : Colors.purple,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Minify',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Minify images and videos to save space.',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    _buildFileList(),
                    const SizedBox(height: 16),
                    _buildSettingsSection(),
                    if (allProcessedFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMinifiedFilesList(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: MacosIconButton(
            padding: const EdgeInsets.all(4),
            onPressed: () async {
              items.value = {};
              isMinifyApp.value = false;
            },
            backgroundColor:
                CupertinoColors.label.resolveFrom(context).withOpacity(.5),
            hoverColor:
                CupertinoColors.label.resolveFrom(context).withOpacity(.9),
            pressedOpacity: .6,
            icon: Icon(
              FluentIcons.dismiss_24_filled,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropTarget(
          label: 'minify-drop',
          onDragEnter: (position) {
            print('onDragEnter: $position');
            haptic.levelChange();
            setState(() {
              isDragging = true;
            });
          },
          onDragExited: () {
            setState(() {
              isDragging = false;
            });
          },
          onDragPerform: (paths) {
            setState(() {
              files.addAll(paths.where(isSupportedFile));
            });
          },
          onDragConclude: () {
            setState(() {
              isDragging = false;
            });
          },
          child: AnimatedContainer(
            duration: Durations.medium2,
            height: 200,
            foregroundDecoration: BoxDecoration(
              border: isDragging
                  ? Border.all(
                      color: CupertinoColors.systemBlue,
                      width: 2,
                    )
                  : Border.all(
                      color: CupertinoColors.systemGrey.withOpacity(.3),
                    ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: files.isEmpty
                ? const Center(
                    child: Text(
                      'Drop files here',
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  )
                : LayoutBuilder(builder: (context, constraints) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 24,
                          child: Center(
                            child: Text(
                              '${files.length} Files',
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
                            controller: _fileScrollController,
                            child: ListView.separated(
                              controller: _fileScrollController,
                              itemCount: files.length,
                              separatorBuilder: (context, index) => Divider(
                                indent: 12,
                                endIndent: 12,
                                height: 1,
                                color:
                                    CupertinoColors.systemGrey.withOpacity(.2),
                              ),
                              itemBuilder: (context, index) {
                                final filePath = files.elementAt(index);
                                final file = File(filePath);
                                final fileName = path.basename(filePath);
                                final fileSize =
                                    formatFileSize(file.lengthSync());
                                final isImage =
                                    //
                                    fileName.toLowerCase().endsWith('.png') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.jpg') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.jpeg') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.webp') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.gif') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.svg') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.heic') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.heif') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.avif') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.bmp') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.tiff') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.jxl') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.ico') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.cur') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.xcf') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.psd') ||
                                        fileName
                                            .toLowerCase()
                                            .endsWith('.ai') ||
                                        fileName.toLowerCase().endsWith('.eps')
                                    //
                                    ;
                                final icon = isImage
                                    ? FluentIcons.image_24_regular
                                    : FluentIcons.video_24_regular;
                                return ContextMenuWidget(
                                  menuProvider: (request) => Menu(
                                    children: [
                                      MenuAction(
                                        callback: () {
                                          Process.run('open', ['-R', filePath]);
                                        },
                                        title: 'Show in Finder',
                                      ),
                                      MenuAction(
                                        callback: () {
                                          setState(() {
                                            files.remove(filePath);
                                          });
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
                    );
                  }),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    bool hasVideos = files.any((file) => isVideoFile(file));
    bool hasImages = files.any((file) => isImageFile(file));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: CupertinoColors.systemGrey.withOpacity(.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [

              if (hasVideos) ...[
                _buildDropdownSetting('Video quality', videoQuality,
                    ['Low', 'Normal', 'High'], minifyInProgress),
                const SizedBox(height: 4),
                _buildDropdownSetting('Video format', videoFormat,
                    ['Same as input', 'MP4', 'WebM'], minifyInProgress),
                const SizedBox(height: 8),
              ],
              if (hasImages) ...[
                _buildDropdownSetting(
                    'Image quality',
                    imageQuality,
                    ['Lowest', 'Low', 'Normal', 'High', 'Highest'],
                    minifyInProgress),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: 300,
                height: 36,
                child: (minifyInProgress)
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ProgressBar(
                              value: (processedFiles / totalFiles) * 100,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Processing: $processedFiles / $totalFiles',
                                style: const TextStyle(fontSize: 12),
                              ),
                              PushButton(
                                controlSize: ControlSize.regular,
                                onPressed: cancelMinification,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : PushButton(
                        controlSize: ControlSize.large,
                        onPressed: (files.isEmpty)
                            ? null
                            : () async {
                                await minifyFiles();
                              },
                        child: const Text(
                          'Minify',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
              ),
              if (errorMessages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Errors:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...errorMessages.map((error) => Text(
                            error,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemRed,
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSetting(
      String label, String value, List<String> options, bool disabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        MacosPopupButton<String>(
          value: value,
          onChanged: disabled
              ? null
              : (newValue) {
                  if (newValue != null) {
                    setState(() {
                      switch (label) {
                        case 'Video quality':
                          videoQuality = newValue;
                          break;
                        case 'Video format':
                          videoFormat = newValue;
                          break;
                        case 'Image quality':
                          imageQuality = newValue;
                          break;
                      }
                    });
                  }
                },
          items: options.map((option) {
            return MacosPopupMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
        ),
      ],
    );
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
