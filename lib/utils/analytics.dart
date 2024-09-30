import 'package:lukehog/lukehog.dart';

final analytics = Lukehog("RFQue2lrnYiWa8JX");

sealed class Analytics {
  static void openApp() => analytics.capture('open_app');
  static void closeApp() => analytics.capture('close_app');
  static void openMinifyApp() => analytics.capture('open_minify_app');
  static void pinFiles() => analytics.capture('pin_files');
  static void archiveFiles() => analytics.capture('archive_files');
  static void minifyImage(String quality) =>
      analytics.capture('minify_image', properties: {'quality': quality});
  static void minifyVideo(String quality, String format) =>
      analytics.capture('minify_video',
          properties: {'quality': quality, 'format': format});
  static void removeFile() => analytics.capture('remove_file');
  static void cancelMinification() => analytics.capture('cancel_minification');
  static void openAboutPage() => analytics.capture('open_about_page');
}
