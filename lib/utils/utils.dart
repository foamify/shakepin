import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_haptic_feedback/macos_haptic_feedback.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';

sealed class AppSizes {
  static const panel = Size(66, 234);
  static const archive = Size(240 + 48 + 12 + 16, 240 + 64);
  static const minify = Size(240 + 48 + 12 + 16, 468);
  static const about = Size(360, 360);
  static const license = Size(360, 450);
  static const misc = Size(240 + 48 + 12 + 16, 468);

  static const pin = Size(240 + 48 + 12 + 16, 240);
}

final haptic = MacosHapticFeedback();

bool isVideoFile(String filePath) {
  final videoExtensions = [
    '.3g2', '.3gp', '.asf', '.avi', '.dv', '.f4v', '.flv', '.gxf', '.m2ts',
    '.m4v', '.mkv', '.mov', '.mp4', '.mpd', '.mpeg', '.mpg', '.mts', '.mxf',
    '.ogg', '.ogv', '.ps', '.ts', '.vob', '.webm', '.wmv', '.wtv',
    // Audio formats that can be in video containers
    // '.aac', '.ac3', '.eac3', '.m4a', '.mp3', '.wav',
    // Less common but supported formats
    // '.rm', '.rmvb', '.swf', '.y4m',
  ];
  return videoExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
}

bool isAudioFile(String filePath) {
  final audioExtensions = [
    '.aac',
    '.ac3',
    '.eac3',
    '.m4a',
    '.mp3',
    '.wav',
  ];
  return audioExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
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
    '.tif',
    '.jxl',
    '.ico',
    '.cur',
    '.xcf',
    '.psd',
    '.ai',
    '.eps',
    '.pdf',
    '.svg',
    '.exr',
    '.hdr',
    '.pbm',
    '.pgm',
    '.ppm',
    '.pnm',
    '.dds',
    '.tga',
    '.miff',
    '.mng',
    '.pcx',
    '.xpm',
    '.xbm',
    '.xwd',
    '.cin',
    '.dpx',
    '.fits',
    '.fts',
    '.fit',
    '.mtv',
    '.palm',
    '.pam',
    '.pcd',
    '.pcl',
    '.pcls',
    '.pct',
    '.pict',
    '.pic',
    '.pix',
    '.ras',
    '.sgi',
    '.sun',
    '.vicar',
    '.viff',
    '.wbmp',
    '.xc',
    '.mat',
    '.mpc',
    '.otb',
    '.pdb',
    '.pfm',
    '.picon',
    '.pix',
    '.rgb',
    '.rgba',
    '.sct',
    '.sfw',
    '.tim',
    '.uil',
    '.vda',
    '.vst',
    '.wpg',
    '.xv'
  ];
  return imageExtensions.any((ext) => filePath.toLowerCase().endsWith(ext));
}

bool isUrl(String path) {
  return path.startsWith('http://') || path.startsWith('https://');
}

String formatFileSize(int size) {
  if (size < 1000) {
    return '$size B';
  } else if (size < 1000 * 1000) {
    return '${(size / 1000).toStringAsFixed(2)} KB';
  } else if (size < 1000 * 1000 * 1000) {
    return '${(size / (1000 * 1000)).toStringAsFixed(2)} MB';
  } else {
    return '${(size / (1000 * 1000 * 1000)).toStringAsFixed(2)} GB';
  }
}

extension ColorExtension on CupertinoDynamicColor {
  Color resolvedColor(BuildContext context) {
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? darkColor
        : color;
  }
}

extension IterableExtension<T> on Iterable<String> {
  bool get containsVideo => any((path) => isVideoFile(path));
  bool get containsImage => any((path) => isImageFile(path));
  Iterable<String> get videoPaths => where((path) => isVideoFile(path));
  Iterable<String> get imagePaths => where((path) => isImageFile(path));
  Iterable<String> get audioPaths => where((path) => isAudioFile(path));
  Iterable<String> get urls => where((path) => isUrl(path));
}

void resetFrameAndHide() async {
  await Future.delayed(Durations.short1);
  final width =
      appMode() == AppMode.panel ? AppSizes.panel.width : AppSizes.pin.width;
  await dropChannel.setFrame(
    Rect.fromCenter(
      center: await dropChannel.center(),
      width: width,
      height: 48,
    ),
    animate: true,
  );
  logger.log('frame adjustment complete');

  await Future.delayed(Durations.short4);
  await dropChannel.setVisible(false);
  logger.log('Window hidden successfully');
}
