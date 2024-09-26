import 'package:flutter/material.dart';
import 'package:shakepin/app/archive_app.dart';
import 'package:shakepin/app/panel_app.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

class BaseApp extends StatefulWidget {
  const BaseApp({super.key});

  @override
  State<BaseApp> createState() => _BaseAppState();
}

class _BaseAppState extends State<BaseApp> with DropListener {
  var isShakeDetected = false;

  @override
  void initState() {
    dropChannel.addListener(this);
    super.initState();
  }

  @override
  void shakeDetected(Offset position) async {
    print('shakeDetected');
    if (!isShakeDetected) {
      print('shakeDetected');
      print('isShakeDetected: $isShakeDetected');
      print('isVisible: ${await dropChannel.isVisible()}');
      isShakeDetected = true;
      print('position: $position');
      await dropChannel.setFrame(
          Rect.fromCenter(
            center: position,
            width: AppSizes.panel.width,
            height: AppSizes.panel.height,
          ),
          animate: false);
      await dropChannel.setVisible(true);
      final center = await dropChannel.center();
      print('center: $center');
    }
    super.shakeDetected(position);
  }

  @override
  void onDragConclude() async {
    isShakeDetected = false;
    print('onDragConclude');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (items().isEmpty) {
        dropChannel.setFrame(
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
    });
    super.onDragConclude();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge([
          archiveProgress,
          items,
          isMinifyApp,
        ]),
        builder: (context, child) {
          if (archiveProgress() > 0) {
            return const ArchiveApp();
          }
          return const PanelApp();
        });
  }
}
