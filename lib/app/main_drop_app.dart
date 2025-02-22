import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/about_app.dart';
import 'package:shakepin/app/crop_app.dart';
import 'package:shakepin/app/license_app.dart';
import 'package:shakepin/app/sections/archive_section/archive_section.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/app/main_drop/main_sidebar.dart';
import 'package:shakepin/app/sections/minify_section/minify_section.dart';
import 'package:shakepin/app/sections/misc_section/misc_section.dart';
import 'package:shakepin/app/setup_app.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/support_banner.dart';

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
      handleDefaultMode();
      resetFrameAndHide();
    }
  }

  @override
  void shakeDetected(Offset position) async {
    logger.log('Shake detected at position: $position');
    if (!isShakeDetected) {
      logger.log('Processing first shake detection');
      isShakeDetected = true;
      final appSize = switch (appMode()) {
        AppMode.panel => AppSizes.panel,
        AppMode.pin => AppSizes.pin,
        AppMode.minify => AppSizes.minify,
        AppMode.archive => AppSizes.archive,
        _ => AppSizes.misc,
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        isAboutApp,
        isLicenseApp,
        isLicenseValid,
        isSetupApp,
        isCropApp,
      ]),
      builder: (context, _) {
        return Stack(
          children: [
            Offstage(
              offstage: isAboutApp() || isLicenseApp() || isSetupApp(),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _isHoveredTop = true),
                    onExit: (_) => setState(() => _isHoveredTop = false),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: MouseRegion(
                            child: Listener(
                              onPointerMove: (event) {
                                dropChannel.startDragging();
                              },
                              child: const ColoredBox(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width,
                          height: MediaQuery.sizeOf(context).height,
                          child: Column(
                            children: [
                              SizedBox(
                                height: 9,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: Durations.long4,
                                    curve: Curves.fastEaseInToSlowEaseOut,
                                    transform: (Matrix4.identity())
                                      ..setTranslationRaw(
                                          appMode() == AppMode.panel
                                              ? _isHoveredTop
                                                  ? 1
                                                  : 6
                                              : _isHoveredTop
                                                  ? -29
                                                  : -24,
                                          appMode() == AppMode.panel ? -6 : -7,
                                          0)
                                      ..scale(_isHoveredTop ? 1.0 : 0.5, 1.0),
                                    child: AnimatedTheme(
                                      data: Theme.of(context).copyWith(
                                        iconTheme: IconThemeData(
                                          color: _isHoveredTop
                                              ? MacosColors.labelColor
                                                  .resolvedColor(context)
                                              : MacosColors.labelColor
                                                  .resolvedColor(context)
                                                  .withValues(alpha: 0.1),
                                        ),
                                      ),
                                      duration: Durations.long4,
                                      curve: Curves.fastEaseInToSlowEaseOut,
                                      child: const Icon(
                                        FluentIcons.line_horizontal_1_16_filled,
                                        size: 24,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        appMode() == AppMode.panel
                                            ? MainAxisAlignment.center
                                            : MainAxisAlignment.start,
                                    children: [
                                      AnimatedOpacity(
                                        duration: Durations.long1,
                                        curve: Curves.easeOutCubic,
                                        opacity:
                                            appMode() == AppMode.panel ? 0 : 1,
                                        child: Offstage(
                                          offstage: appMode() == AppMode.panel,
                                          child: switch (appMode()) {
                                            AppMode.pin ||
                                            AppMode.panel =>
                                              SizedBox(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width -
                                                        48 -
                                                        8,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height -
                                                        9,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 8.0,
                                                    left: 8.0,
                                                    right: 8.0,
                                                  ),
                                                  child: dropSection,
                                                ),
                                              ),
                                            AppMode.minify => SizedBox(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width -
                                                        48 -
                                                        8,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height -
                                                        9,
                                                child: MinifySection(
                                                  dropSection: dropSection,
                                                ),
                                              ),
                                            AppMode.archive => SizedBox(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width -
                                                        48 -
                                                        8,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height -
                                                        9,
                                                child: ArchiveSection(
                                                  dropSection: dropSection,
                                                ),
                                              ),
                                            _ => SizedBox(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width -
                                                        48 -
                                                        8,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height -
                                                        9,
                                                child: MiscSection(
                                                  dropSection: dropSection,
                                                ),
                                              ),
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        height:
                                            MediaQuery.sizeOf(context).height -
                                                16,
                                        child: SingleChildScrollView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          child: MainSidebar(
                                            selectedMode: appMode(),
                                            onModeChanged: handleModeChanged,
                                            onShowTooltip: _handleShowTooltip,
                                            onHideTooltip: _handleHideTooltip,
                                          ),
                                        ),
                                      )
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Offstage(
              offstage: !isAboutApp(),
              child: const AboutApp(),
            ),
            Offstage(
              offstage: !isLicenseApp(),
              child: const LicenseApp(),
            ),
            Offstage(
              offstage: !isSetupApp(),
              child: const SetupApp(),
            ),
            Offstage(
              offstage: !isCropApp(),
              child: const CropApp(),
            ),
            if (!isLicenseValid()) const SupportBanner(),
          ],
        );
      },
    );
  }
}
