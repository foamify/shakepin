import 'dart:ui';

import 'package:macos_haptic_feedback/macos_haptic_feedback.dart';

class AppSizes {
  static const archive = Size(300, 200);
  static const panel = Size(64 * 4, 64);
  static const pin = Size(180, 180);
  static const minify = Size(360, 500);
}

final haptic = MacosHapticFeedback();
