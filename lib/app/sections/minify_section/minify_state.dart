import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

final minifyInProgress = ValueNotifier<bool>(false);
final minifyOneFileProgress = ValueNotifier<double>(0);
final processedFiles = ValueNotifier<int>(0);
final totalFiles = ValueNotifier<int>(0);
final minifiedFiles = ValueNotifier<List<MinifiedFile>>([]);
final errorMessages = ValueNotifier<List<String>>([]);
final retryTrigger = ValueNotifier<String?>(null);
final isShowingAlert = ValueNotifier<bool>(false);
final cropData = ValueNotifier<Map<String, CropValues>>({});

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

class CropValues {
  final int left;
  final int right;
  final int top;
  final int bottom;
  final int width;
  final int height;

  CropValues({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.width,
    required this.height,
  });

  @override
  String toString() {
    return 'CropValues{left: $left, right: $right, top: $top, bottom: $bottom, width: $width, height: $height}';
  }
}

enum ImageQuality {
  lowest,
  low,
  normal,
  high,
  highest,
  lossless; // Add this new value

  String get name => switch (this) {
        ImageQuality.lowest => 'Lowest',
        ImageQuality.low => 'Low',
        ImageQuality.normal => 'Normal',
        ImageQuality.high => 'High',
        ImageQuality.highest => 'Highest',
        ImageQuality.lossless => 'Lossless', // Add this case
      };

  int get value => switch (this) {
        ImageQuality.lowest => 30,
        ImageQuality.low => 50,
        ImageQuality.normal => 80,
        ImageQuality.high => 90,
        ImageQuality.highest => 95,
        ImageQuality.lossless => 100, // Add this case
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

enum ImageDownscale {
  sameAsInput,
  seventyFive,
  fifty,
  twentyFive,
}

extension ImageDownscaleExtension on ImageDownscale {
  String get name {
    return switch (this) {
      ImageDownscale.sameAsInput => 'Same as Input',
      ImageDownscale.seventyFive => '75%',
      ImageDownscale.fifty => '50%',
      ImageDownscale.twentyFive => '25%',
    };
  }

  int get value {
    return switch (this) {
      ImageDownscale.sameAsInput => 100,
      ImageDownscale.seventyFive => 75,
      ImageDownscale.fifty => 50,
      ImageDownscale.twentyFive => 25,
    };
  }
}

enum VideoDownscale {
  sameAsInput,
  seventyFive,
  fifty,
  twentyFive,
}

extension VideoDownscaleExtension on VideoDownscale {
  String get name {
    return switch (this) {
      VideoDownscale.sameAsInput => 'Same as Input',
      VideoDownscale.seventyFive => '75%',
      VideoDownscale.fifty => '50%',
      VideoDownscale.twentyFive => '25%',
    };
  }

  int get value {
    return switch (this) {
      VideoDownscale.sameAsInput => 100,
      VideoDownscale.seventyFive => 75,
      VideoDownscale.fifty => 50,
      VideoDownscale.twentyFive => 25,
    };
  }
}

enum GifQuality {
  low(value: 60),
  medium(value: 80),
  high(value: 90),
  highest(value: 100);

  final int value;
  const GifQuality({required this.value});
}

// Remove GifFps enum since we'll use a slider instead
