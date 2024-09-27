import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:super_context_menu/super_context_menu.dart';
import 'dart:async';

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
  final String oxipngPath;
  final String ffmpegPath;
  final String imageMagickPath;
  final String outputFolder;
  final String imageQuality;
  final String imageFormat;
  final String videoQuality;
  final String videoFormat;
  final bool removeInputFiles;
  Process? _currentProcess;

  MinificationManager({
    required this.oxipngPath,
    required this.ffmpegPath,
    required this.imageMagickPath,
    required this.outputFolder,
    required this.imageQuality,
    required this.imageFormat,
    required this.videoQuality,
    required this.videoFormat,
    required this.removeInputFiles,
  });

  Future<MinifiedFile?> minifyFile(String filePath) async {
    final stopwatch = Stopwatch()..start();
    MinifiedFile? result;

    if (isImageFile(filePath)) {
      result = await minifyImage(filePath);
    } else if (isVideoFile(filePath)) {
      result = await minifyVideo(filePath);
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

  Future<MinifiedFile?> minifyImage(String filePath) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileExtension = path.extension(fileName).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(fileName);

    String outputExtension = fileExtension;
    if (imageFormat != 'Same as input') {
      outputExtension = '.${imageFormat.toLowerCase()}';
    }

    var newFileName = '${fileNameWithoutExtension}_minified$outputExtension';
    var outputPath = outputFolder == 'Same as input'
        ? path.join(path.dirname(filePath), newFileName)
        : path.join(outputFolder, newFileName);

    // Check if the file already exists and generate a unique name if it does
    var counter = 1;
    while (File(outputPath).existsSync()) {
      newFileName =
          '${fileNameWithoutExtension}_minified_$counter$outputExtension';
      outputPath = outputFolder == 'Same as input'
          ? path.join(path.dirname(filePath), newFileName)
          : path.join(outputFolder, newFileName);
      counter++;
    }

    List<String> command;
    if (fileExtension == '.png' && imageFormat == 'Same as input') {
      final qualityArg = switch (imageQuality) {
        'Lowest' => ['-o', '6'],
        'Low' => ['-o', '4'],
        'Medium' => ['-o', '2'],
        'High' => ['-o', '0'],
        _ => ['-o', '2'], // Default to Medium
      };

      command = [
        oxipngPath,
        ...qualityArg,
        '-p', // preserve metadata
        '--force',
        filePath,
        '--out',
        outputPath,
      ];
    } else {
      final qualityArg = switch (imageQuality) {
        'Lowest' => '85',
        'Low' => '90',
        'Medium' => '95',
        'High' => '100',
        _ => '95', // Default to Medium
      };

      command = [
        imageMagickPath,
        'convert',
        filePath,
        '-quality',
        qualityArg,
        outputPath,
      ];
    }

    try {
      _currentProcess = await Process.start(command[0], command.sublist(1));
      final exitCode = await _currentProcess!.exitCode;
      if (exitCode != 0) {
        print(
            'Error minifying image: ${await _currentProcess!.stderr.transform(utf8.decoder).join()}');
        return null;
      } else {
        final originalSize = file.lengthSync();
        final minifiedSize = File(outputPath).lengthSync();

        if (removeInputFiles) {
          await file.delete();
        }

        return MinifiedFile(
          originalPath: filePath,
          minifiedPath: outputPath,
          originalSize: originalSize,
          minifiedSize: minifiedSize,
          duration: const Duration(),
        );
      }
    } catch (e) {
      print('Error minifying image: $e');
      return null;
    }
  }

  Future<MinifiedFile?> minifyVideo(String filePath) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileNameWithoutExtension = path.basenameWithoutExtension(fileName);
    final fileExtension = path.extension(fileName).toLowerCase();

    var outputExtension = fileExtension;
    if (videoFormat != 'Same as input') {
      outputExtension = '.${videoFormat.toLowerCase()}';
    }

    var newFileName = '${fileNameWithoutExtension}_minified$outputExtension';
    var outputPath = outputFolder == 'Same as input'
        ? path.join(path.dirname(filePath), newFileName)
        : path.join(outputFolder, newFileName);

    // Check if the file already exists and generate a unique name if it does
    var counter = 1;
    while (File(outputPath).existsSync()) {
      newFileName =
          '${fileNameWithoutExtension}_minified_$counter$outputExtension';
      outputPath = outputFolder == 'Same as input'
          ? path.join(path.dirname(filePath), newFileName)
          : path.join(outputFolder, newFileName);
      counter++;
    }

    final qualityArg = switch (videoQuality) {
      'Low' => '28',
      'Medium' => '23',
      'High' => '18',
      _ => '23', // Default to Medium
    };

    final command = [
      '-i',
      filePath,
      '-c:v',
      'libx264',
      '-crf',
      qualityArg,
      '-preset',
      'medium',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      outputPath,
    ];

    try {
      _currentProcess = await Process.start(ffmpegPath, command);
      final exitCode = await _currentProcess!.exitCode;
      if (exitCode != 0) {
        print(
            'Error minifying video: ${await _currentProcess!.stderr.transform(utf8.decoder).join()}');
        return null;
      } else {
        final originalSize = file.lengthSync();
        final minifiedSize = File(outputPath).lengthSync();

        if (removeInputFiles) {
          await file.delete();
        }

        return MinifiedFile(
          originalPath: filePath,
          minifiedPath: outputPath,
          originalSize: originalSize,
          minifiedSize: minifiedSize,
          duration: const Duration(),
        );
      }
    } catch (e) {
      print('Error minifying video: $e');
      return null;
    }
  }

  void cancelMinification() {
    _currentProcess?.kill();
  }

  bool isVideoFile(String filePath) {
    final videoExtensions = ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'];
    return videoExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
  }

  bool isImageFile(String filePath) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.heic',
      '.heif',
      '.avif',
      '.tiff',
      '.jxl',
      '.ico',
      '.cur',
      '.xcf',
      '.psd',
      '.ai',
      '.eps'
    ];
    return imageExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
  }
}

class MinifyApp extends StatefulWidget {
  const MinifyApp({super.key});

  @override
  State<MinifyApp> createState() => _MinifyAppState();
}

class _MinifyAppState extends State<MinifyApp> {
  late final SharedPreferences prefs;
  late final TextEditingController oxipngController;
  late final TextEditingController ffmpegController;
  late final TextEditingController imageMagickController;
  final _minifileScrollController = ScrollController();
  final _fileScrollController = ScrollController();

  var oxipngPath = '';
  var ffmpegPath = '';
  var imageMagickPath = '';

  String outputFolder = 'Same as input';
  String videoQuality = 'Medium';
  String videoFormat = 'Same as input';
  String imageQuality = 'Medium';
  String imageFormat = 'PNG';
  bool removeInputFiles = false;
  bool minifyInProgress = false;
  bool minifyFinished = false;
  int processedFiles = 0;
  int totalFiles = 0;
  List<MinifiedFile> minifiedFiles = [];
  List<MinifiedFile> allProcessedFiles = []; // New list to store all processed files

  var files = <String>{};
  var isDragging = false;

  MinificationManager? _minificationManager;

  bool isVideoFile(String filePath) {
    final videoExtensions = ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'];
    return videoExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
  }

  bool isImageFile(String filePath) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.heic',
      '.heif',
      '.avif',
      '.tiff',
      '.jxl',
      '.ico',
      '.cur',
      '.xcf',
      '.psd',
      '.ai',
      '.eps'
    ];
    return imageExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
  }

  bool isSupportedFile(String filePath) {
    return isVideoFile(filePath) || isImageFile(filePath);
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      this.prefs = prefs;
      setState(() {
        oxipngPath = prefs.getString('oxipng_path') ?? '';
        ffmpegPath = prefs.getString('ffmpeg_path') ?? '';
        imageMagickPath = prefs.getString('imagemagick_path') ?? '';

        // Check if the paths are valid
        if (!File(oxipngPath).existsSync()) {
          oxipngPath = '';
          prefs.remove('oxipng_path');
        }
        if (!File(ffmpegPath).existsSync()) {
          ffmpegPath = '';
          prefs.remove('ffmpeg_path');
        }
        if (!File(imageMagickPath).existsSync()) {
          imageMagickPath = '';
          prefs.remove('imagemagick_path');
        }

        oxipngController.text = oxipngPath;
        ffmpegController.text = ffmpegPath;
        imageMagickController.text = imageMagickPath;
      });
    });

    oxipngController = TextEditingController(text: oxipngPath);
    ffmpegController = TextEditingController(text: ffmpegPath);
    imageMagickController = TextEditingController(text: imageMagickPath);

    dropChannel.setMinimumSize(AppSizes.minify);
    files = items().where(isSupportedFile).toSet();
  }

  @override
  void dispose() {
    oxipngController.dispose();
    ffmpegController.dispose();
    imageMagickController.dispose();
    super.dispose();
  }

  Future<void> minifyFiles() async {
    setState(() {
      minifyInProgress = true;
      minifyFinished = false;
      processedFiles = 0;
      totalFiles = files.length;
      minifiedFiles.clear();
    });

    _minificationManager = MinificationManager(
      oxipngPath: oxipngPath,
      ffmpegPath: ffmpegPath,
      imageMagickPath: imageMagickPath,
      outputFolder: outputFolder,
      imageQuality: imageQuality,
      imageFormat: imageFormat,
      videoQuality: videoQuality,
      videoFormat: videoFormat,
      removeInputFiles: removeInputFiles,
    );

    for (final filePath in files) {
      if (!minifyInProgress) break; // Check if cancellation was requested
      final minifiedFile = await _minificationManager!.minifyFile(filePath);
      if (minifiedFile != null) {
        setState(() {
          minifiedFiles.add(minifiedFile);
          allProcessedFiles.add(minifiedFile); // Add to all processed files
          processedFiles++;
        });
      } else {
        setState(() {
          processedFiles++;
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
              itemCount: allProcessedFiles.length, // Use allProcessedFiles instead of minifiedFiles
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
                if (oxipngPath.isEmpty ||
                    ffmpegPath.isEmpty ||
                    imageMagickPath.isEmpty)
                  Column(
                    children: [
                      _buildPathSelector(
                        'Select Oxipng path',
                        oxipngController,
                        (String path) {
                          setState(() {
                            oxipngPath = path;
                            prefs.setString('oxipng_path', path);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPathSelector(
                        'Select FFMPEG path',
                        ffmpegController,
                        (String path) {
                          setState(() {
                            ffmpegPath = path;
                            prefs.setString('ffmpeg_path', path);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPathSelector(
                        'Select ImageMagick path',
                        imageMagickController,
                        (String path) {
                          setState(() {
                            imageMagickPath = path;
                            prefs.setString('imagemagick_path', path);
                          });
                        },
                      ),
                    ],
                  )
                else
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

  Widget _buildPathSelector(String label, TextEditingController controller,
      Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          label.contains('Oxipng')
              ? 'Used for minifying images.'
              : label.contains('FFMPEG')
                  ? 'Used for minifying videos.'
                  : 'Used for minifying images (non-PNG).',
          style:
              const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MacosTextField(
                controller: controller,
                placeholder: 'Path not set',
                readOnly: true,
              ),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              onPressed: () async {
                final result = await openFile(acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'Executable',
                    uniformTypeIdentifiers: ['public.executable'],
                  )
                ]);
                if (result != null) {
                  onSelect(result.path);
                  controller.text = result.path;
                }
              },
              child: const Text('Select'),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                    ['Low', 'Medium', 'High'], minifyInProgress),
                const SizedBox(height: 4),
                _buildDropdownSetting('Video format', videoFormat,
                    ['Same as input', 'MP4', 'WebM'], minifyInProgress),
                const SizedBox(height: 8),
              ],
              if (hasImages) ...[
                _buildDropdownSetting('Image quality', imageQuality,
                    ['Lowest', 'Low', 'Medium', 'High'], minifyInProgress),
                const SizedBox(height: 4),
                _buildDropdownSetting('Image format', imageFormat,
                    ['Same as input', 'PNG', 'JPG', 'WebP'], minifyInProgress),
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
                        onPressed: (oxipngPath.isEmpty ||
                                ffmpegPath.isEmpty ||
                                imageMagickPath.isEmpty ||
                                files.isEmpty)
                            ? null
                            : () async {
                                await minifyFiles();
                              },
                        child: const Text(
                          'Minify',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
              )
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
                        case 'Output folder':
                          outputFolder = newValue;
                          break;
                        case 'Video quality':
                          videoQuality = newValue;
                          break;
                        case 'Video format':
                          videoFormat = newValue;
                          break;
                        case 'Image quality':
                          imageQuality = newValue;
                          break;
                        case 'Image format':
                          imageFormat = newValue;
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
