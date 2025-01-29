import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class SetupApp extends StatelessWidget {
  const SetupApp({super.key});

  void _launchBrewWebsite() async {
    final Uri url = Uri.parse('https://brew.sh');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        setupStep,
        setupSuccess,
        setupError,
      ]),
      builder: (context, child) {
        final step = setupStep();
        Widget content;
        if (setupSuccess() == null && step != null) {
          if (step.progress == 0) {
            initCli();
          }

          // Get current step
          final currentStep = setupStep()?.label ?? 'Checking requirements...';
          final bool isHomebrewStep =
              setupStep() == SetupStep.installingHomebrew ||
                  setupError() == SetupStep.installingHomebrew;

          content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              SizedBox(
                width: 200,
                height: 40,
                child: step.progress == 0
                    ? const Center(child: ProgressCircle())
                    : Center(child: ProgressBar(value: step.progress * 100)),
              ),
              Container(
                width: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: MacosTheme.brightnessOf(context).isDark
                        ? Colors.white.withValues(alpha: .2)
                        : Colors.black.withValues(alpha: .05),
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  color: MacosTheme.brightnessOf(context).isDark
                      ? Colors.white.withValues(alpha: .1)
                      : Colors.black.withValues(alpha: .05),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      currentStep,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: MacosColors.labelColor.resolvedColor(context),
                      ),
                    ),
                    if (isHomebrewStep) ...[
                      const SizedBox(height: 8),
                      Text(
                        'You may need to install Homebrew manually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: MacosColors.systemYellowColor
                              .resolvedColor(context),
                        ),
                      ),
                      GlassButton(
                        padding: EdgeInsets.zero,
                        ghost: true,
                        onTap: _launchBrewWebsite,
                        child: Text(
                          'Visit brew.sh for installation instructions →',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            decoration: TextDecoration.underline,
                            color: MacosColors.systemYellowColor
                                .resolvedColor(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: GlassButton(
                  secondary: true,
                  onTap: () {
                    isSetupApp.value = false;
                    handleModeChanged(AppMode.pin);
                    cli.cancel();
                  },
                  child: const Text('Cancel Setup'),
                ),
              ),
            ],
          );
        } else if (setupError() != null) {
          final bool isHomebrewStep =
              setupError() == SetupStep.installingHomebrew;
          content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 16,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Failed when ',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    ' ${setupError()?.label ?? "setup"} ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      backgroundColor: MacosColors.systemGrayColor
                          .resolvedColor(context)
                          .withValues(alpha: .5),
                    ),
                  ),
                ],
              ),
              if (isHomebrewStep)
                Column(children: [
                  Text(
                    'You need to install Homebrew manually first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          MacosColors.systemYellowColor.resolvedColor(context),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    height: 16,
                    child: GlassButton(
                      padding: EdgeInsets.zero,
                      ghost: true,
                      onTap: _launchBrewWebsite,
                      child: Text(
                        'Visit brew.sh for installation instructions →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          decoration: TextDecoration.underline,
                          color: MacosColors.systemYellowColor
                              .resolvedColor(context),
                        ),
                      ),
                    ),
                  ),
                ]),
              SizedBox(
                width: 200,
                child: GlassButton(
                  child: const Text('Try Again'),
                  onTap: () {
                    initCli();
                  },
                ),
              )
            ],
          );
        } else if (setupSuccess() == false) {
          content = SizedBox(
            width: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                const Text(
                  'An error occurred while setting up.',
                  textAlign: TextAlign.center,
                ),
                GlassButton(
                  child: const Text('Try Again'),
                  onTap: () {
                    initCli();
                  },
                )
              ],
            ),
          );
        } else {
          content = SizedBox(
            width: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Setup complete!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  onTap: () {
                    isSetupApp.value = false;
                    handleModeChanged(AppMode.pin);
                  },
                  child: const Text('Start Using ShakePin'),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Center(child: content),
            Positioned(
              top: 0,
              height: 36,
              left: 0,
              right: 0,
              child: Listener(
                onPointerMove: (event) {
                  dropChannel.startDragging();
                },
                child: const ColoredBox(
                  color: Colors.transparent,
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8)
                    .copyWith(topLeft: const Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  blendMode: BlendMode.src,
                  child: MacosIconButton(
                    borderRadius: BorderRadius.circular(8)
                        .copyWith(topLeft: const Radius.circular(32)),
                    padding: const EdgeInsets.only(
                      left: 6,
                      top: 6,
                      right: 4,
                      bottom: 4,
                    ),
                    onPressed: () {
                      isSetupApp.value = false;
                      handleModeChanged(AppMode.pin);
                    },
                    backgroundColor: CupertinoColors.label
                        .resolveFrom(context)
                        .withValues(alpha: .5),
                    hoverColor: CupertinoColors.label
                        .resolveFrom(context)
                        .withValues(alpha: .9),
                    pressedOpacity: .6,
                    icon: Icon(
                      FluentIcons.dismiss_24_filled,
                      color:
                          CupertinoColors.systemBackground.resolveFrom(context),
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
