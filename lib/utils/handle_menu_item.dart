import 'package:flutter/material.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

void handleMenuItemClicked(int tag) async {
  switch (tag) {
    case 1: // show
      await _showApp();
    case 2: // hide
      await _hideApp();
    case 3: // about
      isAboutApp.value = true;
      _showApp();
    case 4: // reset shared preferences
      await prefs.clear();
    default:
      break;
  }
}

Future<void> _showApp() async {
  final center = await dropChannel.center();
  Size appSize;

  if (isAboutApp()) {
    appSize = AppSizes.about;
  } else {
    appSize = switch (appMode()) {
      AppMode.minify => AppSizes.minify,
      AppMode.misc => AppSizes.misc,
      _ => AppSizes.pin,
    };
  }

  await dropChannel.setFrame(
    Rect.fromCenter(
      center: center,
      width: appSize.width,
      height: appSize.height,
    ),
    animate: true,
  );
  await dropChannel.setVisible(true);
}

Future<void> _hideApp() async {
  resetFrameAndHide();
}
