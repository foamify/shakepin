import 'dart:ui';

import 'package:macos_haptic_feedback/macos_haptic_feedback.dart';

sealed class AppSizes {
  static const archive = Size(300, 200);
  static const panel = Size(64 * 3, 72);
  static const pin = Size(180, 180);
  static const minify = Size(360, 600);
  static const about = Size(360, 360);
}

final haptic = MacosHapticFeedback();

bool isVideoFile(String filePath) {
  final videoExtensions = [
    '.3g2', '.3gp', '.asf', '.avi', '.dv', '.f4v', '.flv', '.gxf', '.m2ts',
    '.m4v', '.mkv', '.mov', '.mp4', '.mpd', '.mpeg', '.mpg', '.mts', '.mxf',
    '.ogg', '.ogv', '.ps', '.ts', '.vob', '.webm', '.wmv', '.wtv',
    // Audio formats that can be in video containers
    '.aac', '.ac3', '.eac3', '.m4a', '.mp3', '.wav',
    // Less common but supported formats
    '.rm', '.rmvb', '.swf', '.y4m',
  ];
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

bool isSupportedFile(String filePath) {
  return isVideoFile(filePath) || isImageFile(filePath);
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