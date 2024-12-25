import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/app/main_drop/main_sidebar.dart';
import 'package:shakepin/app/main_drop/minify_section/minify_section.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

import '../state.dart';

class MainDropApp extends StatefulWidget {
  const MainDropApp({super.key});

  @override
  State<MainDropApp> createState() {
    return _MainDropAppState();
  }
}

class _MainDropAppState extends State<MainDropApp> with DragDropListener {
  var isShakeDetected = false;

  bool _isHoveredTop = false;
  bool _isShowingTooltip = false;
  SelectedMode _selectedMode = SelectedMode.pin;

  @override
  void initState() {
    debugPrint('_MainDropAppState: initState');
    dropChannel.addListener(this);

    items.addListener(() {
      debugPrint('Items changed: ${items().length} items');
      if (items().isEmpty) {
        debugPrint('Items empty, resetting frame and hiding');
        resetFrameAndHide();
      }
    });

    super.initState();
  }

  void resetFrameAndHide() async {
    debugPrint('Starting resetFrameAndHide');
    await dropChannel.setFrame(
      Rect.fromCenter(
        center: await dropChannel.center(),
        width: AppSizes.main.width,
        height: AppSizes.main.height,
      ),
      animate: true,
    );
    debugPrint('First frame adjustment complete');

    await Future.delayed(Durations.short4);
    await dropChannel.setFrame(
      Rect.fromCenter(
        center: await dropChannel.center(),
        width: AppSizes.main.width,
        height: max(AppSizes.main.height / 4, 48),
      ),
      animate: true,
    );
    debugPrint('Second frame adjustment complete');

    await Future.delayed(Durations.short4);
    await dropChannel.setVisible(false);
    debugPrint('Frame hidden');
  }

  @override
  void shakeDetected(Offset position) async {
    debugPrint('Shake detected at position: $position');
    if (!isShakeDetected) {
      debugPrint('Processing first shake detection');
      isShakeDetected = true;
      Size appSize = AppSizes.main;

      debugPrint('Setting frame with size: ${appSize.width}x${appSize.height}');
      await dropChannel.setFrame(
          Rect.fromCenter(
            center: position + Offset(0, appSize.height / 2),
            width: appSize.width,
            height: appSize.height,
          ),
          animate: false);
      await dropChannel.setVisible(true);
      debugPrint('Frame set and made visible');
    }
    super.shakeDetected(position);
  }

  @override
  void onDragConclude() async {
    debugPrint('Drag concluded');
    isShakeDetected = false;

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      debugPrint('Post-frame callback: checking items');
      if (items().isEmpty) {
        debugPrint('No items, resetting frame');
        resetFrameAndHide();
      }
    });

    // Forces addPostFrameCallback to run
    setState(() {});
    super.onDragConclude();
  }

  @override
  void dispose() {
    debugPrint('Disposing _MainDropAppState');
    dropChannel.removeListener(this);
    super.dispose();
  }

  void _handleShowTooltip(String tooltip) {
    debugPrint('Showing tooltip: $tooltip');

    setState(() {
      _isShowingTooltip = true;
    });
    // dropChannel.showPopover(tooltip, edge: PopoverEdge.right);
  }

  void _handleHideTooltip() {
    debugPrint('Hiding tooltip');
    _isShowingTooltip = false;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_isShowingTooltip) {
        debugPrint('Tooltip still not showing, hiding popover');
        // dropChannel.hidePopover();
      } else {
        debugPrint('Tooltip is showing again, not hiding popover');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHoveredTop = true),
          onExit: (_) => setState(() => _isHoveredTop = false),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            child: Column(
              children: [
                SizedBox(
                  height: 8,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(-24, -1.5),
                      child: AnimatedScale(
                        duration: Durations.short4,
                        scale: _isHoveredTop ? 1 : .9,
                        child: AnimatedSwitcher(
                          duration: Durations.short4,
                          child: Icon(
                            FluentIcons.re_order_dots_horizontal_24_filled,
                            size: 12,
                            color: _isHoveredTop
                                ? MacosColors.labelColor.resolvedColor(context)
                                : MacosColors.labelColor
                                    .resolvedColor(context)
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    switch (_selectedMode) {
                      SelectedMode.minify => SizedBox(
                          width: MediaQuery.sizeOf(context).width - 48 - 8,
                          height: MediaQuery.sizeOf(context).height - 16,
                          child: const MinifySection(
                            key: ValueKey('minify_section'),
                          ),
                        ),
                      _ => const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: DropSection(
                            key: ValueKey('drop_section'),
                          ),
                        )
                    },
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height - 16,
                      child: MainSidebar(
                        selectedMode: _selectedMode,
                        onModeChanged: (mode) {
                          setState(() {
                            _selectedMode = mode;
                          });
                        },
                        onShowTooltip: _handleShowTooltip,
                        onHideTooltip: _handleHideTooltip,
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum SelectedMode {
  pin,
  minify,
  archive,
  misc,
}
