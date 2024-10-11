import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/analytics.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:async';
import 'package:libcaesium_dart/libcaesium_dart.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_session.dart';

import '../state.dart';
import '../utils/utils.dart';
import 'minify_app_common.dart';

// Add these enum definitions at the top of the file, outside of any class
enum VideoQuality {
  lowestQuality,
  lowQuality,
  mediumQuality,
  goodQuality,
  highQuality,
  veryHighQuality,
  highestQuality,
  lossless
}

enum ImageQuality { lowest, low, normal, high, highest }

// Add this enum for video formats
enum VideoFormat { webm, mp4 }

class MinificationManager {
  final ImageQuality imageQuality;
  final VideoQuality videoQuality;
  final VideoFormat videoFormat;
  final ImageFormat imageFormat;
  FFmpegSession? currentSession;

  MinificationManager({
    required this.imageQuality,
    required this.videoQuality,
    required this.videoFormat,
    required this.imageFormat,
  });

  Future<MinifiedFile?> minifyFile(String filePath, Directory outputDir) async {
    final stopwatch = Stopwatch()..start();
    MinifiedFile? result;

    if (isImageFile(filePath)) {
      Analytics.minifyImage(imageQuality.name);
      result = await minifyImage(filePath, outputDir);
    } else if (isVideoFile(filePath)) {
      Analytics.minifyVideo(videoQuality.name, videoFormat.name);
      result = await minifyVideo(filePath, outputDir);
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
    final fileNameWithoutExtension = path.basenameWithoutExtension(fileName);

    String inputPath = filePath;
    bool needsConversion =
        path.extension(fileName).toLowerCase() != '.${imageFormat.name}';

    if (needsConversion) {
      try {
        final convertedPath =
            await dropChannel.convertImage(filePath, imageFormat);
        if (convertedPath == null) {
          print('Failed to convert image to ${imageFormat.name}');
          return null;
        }
        inputPath = convertedPath;
      } catch (e) {
        print('Error converting image to ${imageFormat.name}: $e');
        return null;
      }
    }

    var newFileName =
        '${fileNameWithoutExtension}_minified.${imageFormat.name}';
    var outputPath = path.join(downloadsDir.path, newFileName);

    // Check if the file already exists and generate a unique name if it does
    var counter = 1;
    while (File(outputPath).existsSync()) {
      newFileName =
          '${fileNameWithoutExtension}_minified_$counter.${imageFormat.name}';
      outputPath = path.join(downloadsDir.path, newFileName);
      counter++;
    }

    try {
      await compress(
        inputPath: inputPath,
        outputPath: outputPath,
        quality: switch (imageQuality) {
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
      final originalSize = file.lengthSync();
      final minifiedSize = File(outputPath).lengthSync();

      // Clean up the temporary PNG file if we had to convert
      if (needsConversion) {
        await File(inputPath).delete();
      }

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

    final extension = switch (videoFormat) {
      VideoFormat.webm => '.webm',
      VideoFormat.mp4 => '.mp4',
    };

    var newFileName = '${fileNameWithoutExtension}_minified$extension';
    var outputPath = path.join(downloadsDir.path, newFileName);

    // Check if the file already exists and generate a unique name if it does
    var counter = 1;
    while (File(outputPath).existsSync()) {
      newFileName = '${fileNameWithoutExtension}_minified_$counter$extension';
      outputPath = path.join(downloadsDir.path, newFileName);
      counter++;
    }

    final (qualityArg, codec, audioCodec) = switch (videoFormat) {
      VideoFormat.webm => (
          '-crf ${_getVP9QualityArg(videoQuality)}',
          'libvpx-vp9',
          'libopus'
        ),
      VideoFormat.mp4 => (
          '-b:v ${_getHEVCBitrate(videoQuality)}k',
          'hevc_videotoolbox',
          'aac'
        ),
    };

    // at first I thought there's something wrong with the command, but it works just fine in losslesscut but not in IINA

    // final mediaInformation =
    //     (await FFprobeKit.getMediaInformation(filePath)).getMediaInformation();
    // if (mediaInformation == null) {
    //   print('Error getting media information');
    //   return null;
    // }

    // final streams = mediaInformation.getStreams();
    // final videoStream = streams.firstWhere(
    //     (stream) => stream.getStringProperty('codec_type') == 'video');
    // final colorTransfer =
    //     videoStream.getStringProperty('color_transfer') ?? 'bt709';
    // final colorSpace = videoStream.getStringProperty('color_space') ?? 'bt709';
    // final colorPrimaries =
    //     videoStream.getStringProperty('color_primaries') ?? 'bt709';

    String command =
        '-i "$filePath" -c:v $codec $qualityArg -b:a 128k -c:a $audioCodec "$outputPath"';

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

  String _getVP9QualityArg(VideoQuality quality) {
    return switch (quality) {
      VideoQuality.lowestQuality => '40',
      VideoQuality.lowQuality => '36',
      VideoQuality.mediumQuality => '34',
      VideoQuality.goodQuality => '33',
      VideoQuality.highQuality => '32',
      VideoQuality.veryHighQuality => '31',
      VideoQuality.highestQuality => '24',
      VideoQuality.lossless => '0',
    };
  }

  String _getHEVCBitrate(VideoQuality quality) {
    return switch (quality) {
      VideoQuality.lowestQuality => '500',
      VideoQuality.lowQuality => '1000',
      VideoQuality.mediumQuality => '2000',
      VideoQuality.goodQuality => '3500',
      VideoQuality.highQuality => '5000',
      VideoQuality.veryHighQuality => '8000',
      VideoQuality.highestQuality => '12000',
      VideoQuality.lossless => '20000',
    };
  }

  void cancelMinification() {
    Analytics.cancelMinification();
    FFmpegKit.cancel();
    FFmpegKit.cancel(currentSession?.getSessionId());
    currentSession?.cancel();
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

  VideoQuality videoQuality = VideoQuality.goodQuality;
  VideoFormat videoFormat = VideoFormat.mp4;
  ImageQuality imageQuality = ImageQuality.normal;
  ImageFormat imageFormat = ImageFormat.png;
  bool minifyInProgress = false;
  bool minifyFinished = false;
  int processedFiles = 0;
  int totalFiles = 0;

  final files = ValueNotifier<Set<String>>({});
  final isDragging = ValueNotifier<bool>(false);

  MinificationManager? _minificationManager;

  List<String> errorMessages = [];

  @override
  void initState() {
    super.initState();
    minifiedFiles.clear();
    Analytics.openMinifyApp();
    SharedPreferences.getInstance().then((prefs) {
      this.prefs = prefs;
    });
    loadOutputDirectory().then((_) {
      setState(() {});
    });

    dropChannel.setMinimumSize(AppSizes.minify);
    files.value = items().where(isSupportedFile).toSet();
    files.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    minifiedFiles.clear();
  }

  Future<void> minifyFiles() async {
    if (outputDirectory.value == null) {
      await loadOutputDirectory();
      if (outputDirectory.value == null && mounted) {
        await showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const FlutterLogo(size: 56),
            title: const Text('No Output Directory Selected'),
            message:
                const Text('Please select an output directory to continue.'),
            primaryButton: PushButton(
              controlSize: ControlSize.regular,
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      minifyInProgress = true;
      minifyFinished = false;
      processedFiles = 0;
      totalFiles = files().length;
      minifiedFiles.clear();
      errorMessages.clear();
    });

    _minificationManager = MinificationManager(
      imageQuality: imageQuality,
      videoQuality: videoQuality,
      videoFormat: videoFormat,
      imageFormat: imageFormat,
    );

    Directory outputDir = Directory(outputDirectory.value!);

    for (final filePath in files()) {
      if (!minifyInProgress) {
        FFmpegKit.execute("-t 0");
        break;
      }
      final minifiedFile =
          await _minificationManager!.minifyFile(filePath, outputDir);
      if (minifiedFile != null) {
        setState(() {
          minifiedFiles.add(minifiedFile);
          processedFiles++;
        });
      } else {
        setState(() {
          processedFiles++;
          errorMessages.add('Failed to minify: ${path.basename(filePath)}');
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

  Widget _buildSettingsSection() {
    bool hasVideos = files().any((file) => isVideoFile(file));
    bool hasImages = files().any((file) => isImageFile(file));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: CupertinoColors.systemGrey.withOpacity(.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasVideos) ...[
                _buildDropdownSetting(
                  'Video quality',
                  videoQuality,
                  VideoQuality.values,
                  minifyInProgress,
                ),
                const SizedBox(height: 8),
                _buildDropdownSetting(
                  'Video format',
                  videoFormat,
                  VideoFormat.values,
                  minifyInProgress,
                ),
                const SizedBox(height: 8),
              ],
              if (hasImages) ...[
                _buildDropdownSetting(
                  'Image quality',
                  imageQuality,
                  ImageQuality.values,
                  minifyInProgress,
                ),
                const SizedBox(height: 8),
                _buildDropdownSetting(
                  'Image format',
                  imageFormat,
                  ImageFormat.values,
                  minifyInProgress,
                ),
              ],
              const SizedBox(height: 16),
              MacosTextField(
                placeholder: 'Output Directory',
                prefix: const MacosIcon(CupertinoIcons.folder),
                controller: TextEditingController(text: outputDirectory.value),
                readOnly: true,
                maxLines: 1,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
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
                                controlSize: ControlSize.small,
                                onPressed: cancelMinification,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: PushButton(
                              controlSize: ControlSize.large,
                              onPressed: (files().isEmpty ||
                                      outputDirectory.value == null)
                                  ? null
                                  : minifyFiles,
                              child: const Text(
                                'Minify',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PushButton(
                            controlSize: ControlSize.large,
                            onPressed: () => loadOutputDirectory(),
                            child: MacosIcon(
                              CupertinoIcons.folder,
                              size: 16,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ],
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
                        case 'Image quality':
                          imageQuality = newValue as ImageQuality;
                          break;
                        case 'Video format':
                          videoFormat = newValue as VideoFormat;
                          break;
                        case 'Image format':
                          imageFormat = newValue as ImageFormat;
                          break;
                      }
                    });
                  }
                },
          items: options.map((option) {
            return MacosPopupMenuItem<T>(
              value: option,
              child: Text(label == 'Image format'
                  ? option.name.toLowerCase()
                  : formatEnumName(option.name)),
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
                    if (minifiedFiles().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      buildMinifiedFilesList(
                          minifiedFiles(), _minifileScrollController),
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
              _minificationManager?.cancelMinification();
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
