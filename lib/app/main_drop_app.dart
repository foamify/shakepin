import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/sections/archive_section/archive_section.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/app/main_drop/main_sidebar.dart';
import 'package:shakepin/app/sections/minify_section/minify_section.dart';
import 'package:shakepin/app/sections/misc_section/misc_section.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';

import '../state.dart';

final dropSectionKey = GlobalKey();

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
  final bool _isShowingTooltip = false;

  @override
  void initState() {
    logger.log('_MainDropAppState: initState');
    dropChannel.addListener(this);

    items.addListener(itemListener);

    super.initState();
  }

  @override
  void dispose() {
    logger.log('Disposing _MainDropAppState');
    dropChannel.removeListener(this);
    items.removeListener(itemListener);
    super.dispose();
  }

  void itemListener() {
    logger.log('Items changed: ${items().length} items');
    if (items().isEmpty) {
      logger.log('Items empty, resetting frame and hiding');
      resetFrameAndHide();
      handleModeChanged(AppMode.pin);
    }
  }

  @override
  void shakeDetected(Offset position) async {
    logger.log('Shake detected at position: $position');
    if (!isShakeDetected) {
      logger.log('Processing first shake detection');
      isShakeDetected = true;
      final appSize = switch (appMode()) {
        AppMode.pin => AppSizes.pin,
        AppMode.minify => AppSizes.minify,
        AppMode.archive => AppSizes.archive,
        AppMode.misc => AppSizes.misc,
      };

      logger.log('Setting frame with size: ${appSize.width}x${appSize.height}');
      await dropChannel.setFrame(
          Rect.fromCenter(
            center: position + Offset(0, appSize.height / 2),
            width: appSize.width,
            height: appSize.height,
          ),
          animate: false);
      await dropChannel.setVisible(true);
      logger.log('Frame set and made visible');
    }
    super.shakeDetected(position);
  }

  @override
  void onDragConclude() async {
    // logger.log('Drag concluded');
    isShakeDetected = false;

    Future.delayed(const Duration(milliseconds: 100), () {
      logger.log('Post-frame callback: checking items');
      if (items().isEmpty) {
        logger.log('No items, resetting frame');
        resetFrameAndHide();
      }
    });

    // Forces addPostFrameCallback to run
    setState(() {});
    super.onDragConclude();
  }

  void _handleShowTooltip(String tooltip) {
    // logger.log('Showing tooltip: $tooltip');

    // setState(() {
    //   _isShowingTooltip = true;
    // });
    // // dropChannel.showPopover(tooltip, edge: PopoverEdge.right);
  }

  void _handleHideTooltip() {
    // logger.log('Hiding tooltip');
    // _isShowingTooltip = false;
    // Future.delayed(const Duration(milliseconds: 700), () {
    //   if (!_isShowingTooltip) {
    //     logger.log('Tooltip still not showing, hiding popover');
    //     // dropChannel.hidePopover();
    //   } else {
    //     logger.log('Tooltip is showing again, not hiding popover');
    //   }
    // });
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
                ListenableBuilder(
                  listenable: appMode,
                  builder: (context, _) {
                    final dropSection = DropSection(
                      key: dropSectionKey,
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        switch (appMode()) {
                          AppMode.minify => SizedBox(
                              width: MediaQuery.sizeOf(context).width - 48 - 8,
                              height: MediaQuery.sizeOf(context).height - 8,
                              child: MinifySection(
                                dropSection: dropSection,
                              ),
                            ),
                          AppMode.misc => SizedBox(
                              width: MediaQuery.sizeOf(context).width - 48 - 8,
                              height: MediaQuery.sizeOf(context).height - 16,
                              child: MiscSection(
                                dropSection: dropSection,
                              ),
                            ),
                          AppMode.archive => SizedBox(
                              width: MediaQuery.sizeOf(context).width - 48 - 8,
                              height: MediaQuery.sizeOf(context).height - 8,
                              child: ArchiveSection(
                                dropSection: dropSection,
                              ),
                            ),
                          _ => SizedBox(
                              width: MediaQuery.sizeOf(context).width - 48 - 8,
                              height: MediaQuery.sizeOf(context).height - 8,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8.0,
                                  left: 4.0,
                                  right: 8.0,
                                ),
                                child: dropSection,
                              ),
                            )
                        },
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height - 16,
                          child: MainSidebar(
                            selectedMode: appMode(),
                            onModeChanged: handleModeChanged,
                            onShowTooltip: _handleShowTooltip,
                            onHideTooltip: _handleHideTooltip,
                          ),
                        )
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void handleModeChanged(AppMode mode) async {
    final appSize = switch (mode) {
      AppMode.pin => AppSizes.pin,
      AppMode.minify => AppSizes.minify,
      AppMode.archive => AppSizes.archive,
      AppMode.misc => AppSizes.misc,
    };

    appMode.value = mode;

    dropChannel.setMinimumSize(appSize);
    final rect = Rect.fromCenter(
      center: await dropChannel.center(),
      width: appSize.width,
      height: appSize.height,
    );
    dropChannel.setFrame(rect, animate: true);
  }
}
