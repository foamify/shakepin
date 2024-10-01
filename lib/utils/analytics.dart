import 'package:lukehog/lukehog.dart';
import 'package:shakepin/state.dart';

final analytics = Lukehog("RFQue2lrnYiWa8JX");

sealed class Analytics {
  static void openApp() => !isAppStore ? analytics.capture('open_app') : null;
  static void closeApp() => !isAppStore ? analytics.capture('close_app') : null;
  static void openMinifyApp() =>
      !isAppStore ? analytics.capture('open_minify_app') : null;
  static void pinFiles() => !isAppStore ? analytics.capture('pin_files') : null;
  static void archiveFiles() =>
      !isAppStore ? analytics.capture('archive_files') : null;
  static void minifyImage(String quality) => !isAppStore
      ? analytics.capture('minify_image', properties: {'quality': quality})
      : null;
  static void minifyVideo(String quality, String format) => !isAppStore
      ? analytics.capture('minify_video',
          properties: {'quality': quality, 'format': format})
      : null;
  static void removeFile() =>
      !isAppStore ? analytics.capture('remove_file') : null;
  static void cancelMinification() =>
      !isAppStore ? analytics.capture('cancel_minification') : null;
  static void openAboutPage() =>
      !isAppStore ? analytics.capture('open_about_page') : null;
}
