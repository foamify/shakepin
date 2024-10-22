import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shakepin/app/about_app.dart';
import 'package:shakepin/app/archive_app.dart';
import 'package:shakepin/app/minify_app.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/app/panel_app.dart';
import 'package:shakepin/app/pin_app.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drag_to_move_area.dart';
import 'package:shakepin/widgets/multi_hit_stack.dart';

class BaseApp extends StatefulWidget {
  const BaseApp({super.key});

  @override
  State<BaseApp> createState() => _BaseAppState();
}

class _BaseAppState extends State<BaseApp> with DragDropListener {
  var isShakeDetected = false;

  @override
  void initState() {
    dropChannel.addListener(this);

    items.addListener(() {
      if (items().isEmpty) {
        resetFrameAndHide();
      }
    });

    isAboutApp.addListener(() {
      if (!isAboutApp()) {
        resetFrameAndHide();
      }
    });

    isMinifyApp.addListener(() async {
      if (isMinifyApp()) {
        dropChannel.setFrame(
          Rect.fromCenter(
            center: await dropChannel.center(),
            width: AppSizes.minify.width,
            height: AppSizes.minify.height,
          ),
          animate: true,
        );
      }
    });

    minifiedFiles.addListener(() async {
      if (minifiedFiles().isNotEmpty && isMinifyApp()) {
        dropChannel.setFrame(
          Rect.fromCenter(
            center: await dropChannel.center(),
            width: AppSizes.minify.width,
            height: AppSizes.minify.height + 200,
          ),
          animate: true,
        );
      }
    });

    super.initState();
  }

  void resetFrameAndHide() async {
    await dropChannel.setFrame(
      Rect.fromCenter(
        center: await dropChannel.center(),
        width: AppSizes.panel.width,
        height: AppSizes.panel.height,
      ),
      animate: true,
    );
    await Future.delayed(Durations.short4);
    await dropChannel.setFrame(
      Rect.fromCenter(
        center: await dropChannel.center(),
        width: AppSizes.panel.width,
        height: 1,
      ),
      animate: true,
    );
    await Future.delayed(Durations.short4);
    await dropChannel.setVisible(false);
  }

  @override
  void shakeDetected(Offset position) async {
    if (isAboutApp()) {
      return;
    }
    if (!isShakeDetected) {
      isShakeDetected = true;
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
            center: position + Offset(0, appSize.height / 2),
            width: appSize.width,
            height: appSize.height,
          ),
          animate: false);
      await dropChannel.setVisible(true);
    }
    super.shakeDetected(position);
  }

  @override
  void onDragConclude() async {
    isShakeDetected = false;
    // print('onDragConclude');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (items().isEmpty) {
        resetFrameAndHide();
      }
    });
    super.onDragConclude();
  }

  @override
  void dispose() {
    dropChannel.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: const [],
      child: MultiHitStack(
        children: [
          const Positioned.fill(
            child: DragToMoveArea(
              child: SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: ListenableBuilder(
                listenable: Listenable.merge([
                  archiveProgress,
                  items,
                  isMinifyApp,
                  isAboutApp,
                ]),
                builder: (context, child) {
                  if (isAboutApp()) {
                    return const AboutApp();
                  }
                  if (isMinifyApp()) {
                    return const MinifyApp();
                  }
                  if (archiveProgress() >= 0) {
                    return const ArchiveApp();
                  }
                  if (items().isNotEmpty) {
                    return const PinApp();
                  }
                  return const PanelApp();
                }),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Icon(
                FluentIcons.re_order_dots_horizontal_24_filled,
                color: CupertinoColors.label.resolveFrom(context),
                size: 16,
              ),
            ),
          )
        ],
      ),
    );
  }
}
