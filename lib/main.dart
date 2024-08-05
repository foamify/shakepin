import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'utils/constant.dart';
import 'utils/detect_shake.dart';
import 'utils/state.dart';

final cursorPos = Signal(Offset.zero);
var initialCursorPos = Offset.zero;
var pasteBoardCount = 0;

List<Duration> timestamps = [];

Timer cursorTimer = Timer(Duration.zero, () {});

void main(List<String> args) async {
  // print('init1');
  WidgetsFlutterBinding.ensureInitialized();
  // print('init2');
  await windowManager.ensureInitialized();
  WindowManipulator.initialize();
  // print('init3');
  runApp(const DropApp());

  windowManager.setAlwaysOnTop(true);
  windowManager.setVisibleOnAllWorkspaces(true);
  windowManager.setSkipTaskbar(true);
  windowManager.setMinimumSize(windowSize);
  await windowManager.waitUntilReadyToShow();
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
      windowButtonVisibility: false);
  windowManager.setSize(windowSize);
  windowManager.show();
  windowManager.minimize();
  // windowManager.setSize(windowSize);

  // windowManager
  //   ..setSize(windowSize)
  //   // ..setFrame((initialCursorPos + const Offset(0, 20)) & windowSize)
  //   ..setAlwaysOnTop(true)
  //   ..show();
  isVisible = true;

  _initShakeDetector();

  _initTray();
}

void _initTray() async {
  await trayManager.setIcon(
    defaultTargetPlatform == TargetPlatform.windows
        ? "assets/images/tray_icon.ico"
        : "assets/images/tray_icon.png",
  );

  await trayManager.setContextMenu(Menu(
    items: [
      MenuItem(
        label: 'Show',
        onClick: (item) {
          windowManager.show(inactive: true);
        },
      ),
      MenuItem(
        label: 'Hide',
        onClick: (item) {
          windowManager.minimize();
        },
      ),
      MenuItem(
        label: 'Quit',
        onClick: (item) {
          exit(1);
        },
      ),
    ],
  ));
}

void _initShakeDetector() {
  cursorTimer.cancel();

  cursorTimer = Timer.periodic(const Duration(milliseconds: 16), (_) async {
    final leftClick = await windowManager.getLeftClick();
    pasteBoardCount = await windowManager.getPasteboard();
    if (leftClick) {
      cursorPos.value = await windowManager.getCursorPos();
      // print(pasteBoard);
    } else {
      if (items.isEmpty && pasteBoardCount > 0 && !hover) {
        isVisible = false;
        print(positions.length);
        unawaited(windowManager.clearPasteboard());
      }
      positions.clear();
    }
    // final pasteboard = await windowManager.getPasteboard();
    // print(pasteboard);
  });
  cursorPos.subscribe((Offset offset) async {
    if (positions.isEmpty) {
      initialCursorPos = offset;
    }
    if (timestamps.isNotEmpty &&
        DateTime.fromMillisecondsSinceEpoch(timestamps.last.inMilliseconds)
                .difference(DateTime.now())
                .inMilliseconds >
            1000) {
      positions.clear();
      timestamps.clear();
    }
    positions.add(offset);
    timestamps
        .add(DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(0)));
    if (positions.length > shakeThreshold) {
      positions.removeAt(0);
    }

    bool isShake = detectShake(positions, timestamps);
    if (isShake) {
      pasteBoardCount = await windowManager.getPasteboard();
      if (pasteBoardCount > 0 && !isVisible) {
        // print(pasteBoardCount);
        print('SHAKE!');

        await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
            windowButtonVisibility: false);
        var pos = (offset + const Offset(-90, 20));
        windowManager
          ..setFrame(pos & windowSize)
          ..setAlwaysOnTop(true)
          ..show()
          ..unmaximize();
        isVisible = true;
      }
    }
    // _positions.clear();
  });
}
