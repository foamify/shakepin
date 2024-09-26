import 'package:flutter/material.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

void handleMenuItemClicked(int tag) async {
  switch (tag) {
    case 1: // show
      await _showApp();
      break;
    case 2: // hide
      await _hideApp();
      break;
    default:
      break;
  }
}

Future<void> _showApp() async {
  final center = await dropChannel.center();
  Size appSize;

  if (isMinifyApp()) {
    appSize = AppSizes.minify;
  } else if (archiveProgress() >= 0) {
    appSize = AppSizes.archive;
  } else if (items().isNotEmpty) {
    appSize = AppSizes.pin;
  } else {
    appSize = AppSizes.panel;
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
  final center = await dropChannel.center();
  Size appSize;

  if (isMinifyApp()) {
    appSize = AppSizes.minify;  
  } else if (archiveProgress() >= 0) {
    appSize = AppSizes.archive;
  } else if (items().isNotEmpty) {
    appSize = AppSizes.pin;
  } else {
    appSize = AppSizes.panel;
  }

  await dropChannel.setFrame(
    Rect.fromCenter(
      center: center,
      width: appSize.width,
      height: appSize.height,
    ),
    animate: true,
  );
  await Future.delayed(Durations.short4);
  await dropChannel.setFrame(
    Rect.fromCenter(
      center: center,
      width: appSize.width,
      height: 1,
    ),
    animate: true,
  );
  await Future.delayed(Durations.short4);
  await dropChannel.setVisible(false);
}
