import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../state.dart';
import '../utils/analytics.dart';
import '../utils/drop_channel.dart';
import '../utils/utils.dart';
import 'minify_app_common.dart';

enum ImageFormat { sameAsInput, png, jpg, webp, tiff }

class MinificationManager {
  final String oxipngPath;
  final String ffmpegPath;
  final String imageMagickPath;
  final String outputFolder;
  final ImageQuality imageQuality;
  final ImageFormat imageFormat;
  final VideoQuality videoQuality;
  final VideoFormat videoFormat;
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
      Analytics.minifyImage(imageQuality.name);
      result = await minifyImage(filePath);
    } else if (isVideoFile(filePath)) {
      Analytics.minifyVideo(videoQuality.name, videoFormat.name);
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
    if (imageFormat != ImageFormat.sameAsInput) {
      outputExtension = '.${imageFormat.name}';
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
    if (fileExtension == '.png' && imageFormat == ImageFormat.sameAsInput) {
      final qualityArg = switch (imageQuality) {
        ImageQuality.lowest => ['-o', '6'],
        ImageQuality.low => ['-o', '4'],
        ImageQuality.normal => ['-o', '2'],
        ImageQuality.high => ['-o', '0'],
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
        ImageQuality.lowest => '85',
        ImageQuality.low => '90',
        ImageQuality.normal => '95',
        ImageQuality.high => '100',
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
    if (videoFormat != VideoFormat.sameAsInput) {
      outputExtension = '.${videoFormat.name}';
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
      VideoQuality.lowQuality => '17',
      VideoQuality.mediumQuality => '23',
      VideoQuality.highQuality => '28',
      _ => '23', // Default to Medium
    };

    List<String> command;
    if (videoFormat == VideoFormat.webm) {
      command = [
        '-i',
        filePath,
        '-c:v',
        'libvpx',
        '-crf',
        qualityArg,
        '-b:v',
        '1M',
        '-c:a',
        'libvorbis',
        '-b:a',
        '128k',
        outputPath,
      ];
    } else {
      command = [
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
    }

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
  VideoQuality videoQuality = VideoQuality.mediumQuality;
  VideoFormat videoFormat = VideoFormat.mp4;
  ImageFormat imageFormat = ImageFormat.png;
  ImageQuality imageQuality = ImageQuality.normal;
  bool removeInputFiles = false;
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

  @override
  void initState() {
    super.initState();
    Analytics.openMinifyApp();
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
      errorMessages.clear(); // Clear previous error messages
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
    Analytics.cancelMinification();
    _minificationManager?.cancelMinification();
    setState(() {
      minifyInProgress = false;
    });
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
              : label.contains('FFmpeg')
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
                    VideoQuality.values, minifyInProgress),
                const SizedBox(height: 4),
                _buildDropdownSetting('Video format', videoFormat,
                    VideoFormat.values, minifyInProgress),
                const SizedBox(height: 8),
              ],
              if (hasImages) ...[
                _buildDropdownSetting('Image quality', imageQuality,
                    ImageQuality.values, minifyInProgress),
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

  Widget _buildDropdownSetting<T extends Enum>(
      String label, T value, List<T> options, bool disabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        MacosPopupButton<T>(
          value: value,
          onChanged: disabled
              ? null
              : (newValue) {
                  if (newValue != null) {
                    setState(() {
                      switch (label) {
                        case 'Video quality':
                          videoQuality = newValue as VideoQuality;
                          break;
                        case 'Video format':
                          videoFormat = newValue as VideoFormat;
                          break;
                        case 'Image quality':
                          imageQuality = newValue as ImageQuality;
                          break;
                      }
                    });
                  }
                },
          items: options.map((option) {
            return MacosPopupMenuItem<T>(
              value: option,
              child: Text(formatEnumName(option.name)),
            );
          }).toList(),
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
                        'Select FFmpeg path',
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
                      buildFileList(
                        files,
                        isDragging,
                        _fileScrollController,
                        (String filePath) {
                          setState(() {
                            files.remove(filePath);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsSection(),
                      if (allProcessedFiles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        buildMinifiedFilesList(
                            allProcessedFiles, _minifileScrollController),
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
}
