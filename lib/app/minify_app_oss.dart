import 'dart:convert';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/widgets/native_dropdown_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state.dart';
import '../utils/analytics.dart';
import '../utils/drop_channel.dart';
import '../utils/utils.dart';
import 'minify_app_common.dart';

enum ImageFormat { sameAsInput, png, jpg, webp, tiff }

enum VideoFormat { webm, mp4, gif }

class MinificationManager {
  final String outputFolder;
  final ImageQuality imageQuality;
  final ImageFormat imageFormat;
  final VideoQuality videoQuality;
  final VideoFormat videoFormat;
  final bool removeInputFiles;
  Process? _currentProcess;

  MinificationManager({
    required this.outputFolder,
    required this.imageQuality,
    required this.imageFormat,
    required this.videoQuality,
    required this.videoFormat,
    required this.removeInputFiles,
  });

  int _getGifWidth(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.lowestQuality:
        return 320;
      case VideoQuality.lowQuality:
        return 480;
      case VideoQuality.mediumQuality:
        return 640;
      case VideoQuality.goodQuality:
        return 800;
      case VideoQuality.highQuality:
        return 1024;
      case VideoQuality.veryHighQuality:
        return 1280;
      case VideoQuality.highestQuality:
        return 1920;
      case VideoQuality.lossless:
        return 2560;
    }
  }

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

    return await minifyImageWithCaesium(
      filePath,
      outputPath,
      imageQuality,
      removeInputFile: removeInputFiles,
    );
  }

  Future<MinifiedFile?> minifyVideo(String filePath) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileNameWithoutExtension = path.basenameWithoutExtension(fileName);

    String outputExtension = switch (videoFormat) {
      VideoFormat.webm => '.webm',
      VideoFormat.mp4 => '.mp4',
      VideoFormat.gif => '.gif',
    };

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

    // Base command with hardware acceleration and progress reporting
    List<String> baseCommand = [
      '-hwaccel',
      'auto',
      '-progress',
      'pipe:1',
      '-y',
      '-i',
      filePath,
    ];

    List<String> encodingParams;
    if (videoFormat == VideoFormat.gif) {
      encodingParams = [
        '-vf',
        // This FFmpeg filter command does the following:
        // 1. 'fps=10': Sets the frame rate to 10 frames per second
        // 2. 'scale=width:-1:flags=lanczos': Scales the width based on quality, maintaining aspect ratio, using Lanczos scaling
        // 3. 'split[s0][s1]': Splits the video stream into two identical streams
        // 4. '[s0]palettegen[p]': Generates a palette from the first stream
        // 5. '[s1][p]paletteuse': Applies the generated palette to the second stream
        // This combination optimizes the GIF for size and quality
        'fps=10,scale=${_getGifWidth(videoQuality)}:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse',
        '-loop', '0',
        outputPath,
      ];
    } else {
      final qualityArg = switch (videoQuality) {
        VideoQuality.lowestQuality => '51',
        VideoQuality.lowQuality => '40',
        VideoQuality.mediumQuality => '30',
        VideoQuality.goodQuality => '23',
        VideoQuality.highQuality => '18',
        VideoQuality.veryHighQuality => '12',
        VideoQuality.highestQuality => '6',
        VideoQuality.lossless => '0',
      };

      if (videoFormat == VideoFormat.webm) {
        encodingParams = [
          '-c:v', 'libvpx-vp9', // Using VP9 for better quality
          '-crf', qualityArg,
          '-b:v', '0', // Let CRF control quality
          '-deadline', 'good', // Balanced encoding speed
          '-cpu-used', '2', // Balanced CPU usage
          '-pix_fmt', 'yuv420p', // Ensure compatibility
          '-c:a', 'libopus', // Better audio codec
          outputPath,
        ];
      } else {
        // Calculate optimal bitrate based on resolution
        final probe = await _probeVideoInfo(filePath);
        final maxRate = _calculateOptimalBitrate(probe);
        final bufSize = maxRate * 2;

        encodingParams = [
          '-c:v', 'libx264',
          '-preset', 'fast', // Faster encoding
          '-crf', qualityArg,
          if (maxRate > 0) ...[
            '-maxrate',
            '${maxRate}k',
            '-bufsize',
            '${bufSize}k',
          ],
          '-pix_fmt', 'yuv420p', // Ensure compatibility
          '-profile:v', 'high', // High profile for better compression
          '-level', '4.1', // Widely compatible level
          '-movflags', '+faststart', // Enable streaming
          '-c:a', 'aac', // AAC audio codec
          '-b:a', '128k', // Decent audio quality
          outputPath,
        ];
      }
    }

    final command = [...baseCommand, ...encodingParams];

    try {
      _currentProcess = await Process.start('ffmpeg', command);

      // Handle progress reporting
      _currentProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _parseProgress(line);
      });

      // Collect error output
      final errorBuffer = StringBuffer();
      _currentProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(errorBuffer.writeln);

      final exitCode = await _currentProcess!.exitCode;
      if (exitCode != 0) {
        print('FFmpeg error: ${errorBuffer.toString()}');
        return null;
      }

      final originalSize = file.lengthSync();
      final minifiedSize = File(outputPath).lengthSync();
      final duration = await _getVideoDuration(outputPath);

      if (removeInputFiles) {
        await file.delete();
      }

      return MinifiedFile(
        originalPath: filePath,
        minifiedPath: outputPath,
        originalSize: originalSize,
        minifiedSize: minifiedSize,
        duration: duration,
      );
    } catch (e, stackTrace) {
      print('Error minifying video: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Helper function to probe video information
  Future<Map<String, dynamic>> _probeVideoInfo(String filePath) async {
    try {
      final result = await Process.run(
        'ffprobe',
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          filePath,
        ],
      );

      if (result.exitCode == 0) {
        return json.decode(result.stdout as String);
      }
    } catch (e) {
      print('Error probing video: $e');
    }
    return {};
  }

  // Calculate optimal bitrate based on video resolution
  int _calculateOptimalBitrate(Map<String, dynamic> probe) {
    try {
      final streams = probe['streams'] as List;
      final videoStream = streams.firstWhere(
        (stream) => stream['codec_type'] == 'video',
        orElse: () => {},
      );

      if (videoStream.isEmpty) return 0;

      final width = videoStream['width'] as int;
      final height = videoStream['height'] as int;
      final pixels = width * height;

      // Calculate bitrate based on resolution
      // These are conservative estimates for good quality
      if (pixels <= 921600) {
        // 1280x720
        return 5000; // 5 Mbps
      } else if (pixels <= 2073600) {
        // 1920x1080
        return 8000; // 8 Mbps
      } else if (pixels <= 8294400) {
        // 4K
        return 16000; // 16 Mbps
      } else {
        return 20000; // > 4K
      }
    } catch (e) {
      print('Error calculating bitrate: $e');
      return 0;
    }
  }

  // Get video duration using ffprobe
  Future<Duration> _getVideoDuration(String filePath) async {
    try {
      final result = await Process.run(
        'ffprobe',
        [
          '-v',
          'quiet',
          '-show_entries',
          'format=duration',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          filePath,
        ],
      );

      if (result.exitCode == 0) {
        final seconds = double.parse(result.stdout.toString().trim());
        return Duration(milliseconds: (seconds * 1000).round());
      }
    } catch (e) {
      print('Error getting video duration: $e');
    }
    return const Duration();
  }

  // Parse FFmpeg progress output
  void _parseProgress(String line) {
    if (line.contains('time=')) {
      final timeMatch = RegExp(r'time=(\d+:\d+:\d+.\d+)').firstMatch(line);
      if (timeMatch != null) {
        // You can emit progress updates here
        // For example, using a StreamController or callback
      }
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
  // TODO: none of these works
  final _minifileScrollController = ScrollController();
  final _fileScrollController = ScrollController();

  String outputFolder = 'Same as input';
  VideoQuality videoQuality = VideoQuality.mediumQuality;
  VideoFormat videoFormat = VideoFormat.mp4;
  ImageFormat imageFormat = ImageFormat.sameAsInput;
  ImageQuality imageQuality = ImageQuality.normal;
  bool removeInputFiles = false;
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

    dropChannel.setMinimumSize(AppSizes.minify);
    files.value = items().where(isSupportedFile).toSet();
    files.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    minifiedFiles.clear();
    super.dispose();
  }

  Future<void> minifyFiles() async {
    setState(() {
      minifyInProgress = true;
      minifyFinished = false;
      processedFiles = 0;
      totalFiles = files().length;
      minifiedFiles.clear();
      errorMessages.clear(); // Clear previous error messages
    });

    _minificationManager = MinificationManager(
      outputFolder: outputFolder,
      imageQuality: imageQuality,
      imageFormat: imageFormat,
      videoQuality: videoQuality,
      videoFormat: videoFormat,
      removeInputFiles: removeInputFiles,
    );

    for (final filePath in files()) {
      if (!minifyInProgress) break; // Check if cancellation was requested
      final minifiedFile = await _minificationManager!.minifyFile(filePath);
      if (minifiedFile != null) {
        setState(() {
          minifiedFiles.add(minifiedFile);
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
                const SizedBox(height: 4),
                _buildDropdownSetting('Image format', imageFormat,
                    ImageFormat.values, minifyInProgress),
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
                        onPressed: (files().isEmpty)
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
        IntrinsicWidth(
          child: NativeDropdownButton<T>(
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
                          case 'Image format':
                            imageFormat = newValue as ImageFormat;
                            break;
                        }
                      });
                    }
                  },
            items: options.map((option) {
              return NativeDropdownItem<T>(
                value: option,
                label: label == 'Image format'
                    ? option.name.toLowerCase()
                    : formatEnumName(option.name),
              );
            }).toList(),
            child: Text(
              label == 'Image format'
                  ? value.name.toLowerCase()
                  : formatEnumName(value.name),
              style: const TextStyle(fontSize: 12),
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
