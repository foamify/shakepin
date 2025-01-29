import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libcaesium_dart/libcaesium_dart.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop_app.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/license_service.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:shakepin/widgets/native_dropdown_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  await RustLib.init();
  WidgetsFlutterBinding.ensureInitialized();
  LicenseService.instance;
  await DropdownChannel.instance.initialize();
  
  // Setup auto updater
  autoUpdater
    ..setFeedURL('https://skpn-dl.damywise.com/skpn-appcast.xml')
    ..addListener(_UpdaterListener()) // Add listener
    ..checkForUpdates(inBackground: true)
    ..setScheduledCheckInterval(86400);

  initCli();

  prefs = await SharedPreferences.getInstance();

  dropChannel.setTrayIcon(
    Uint8List.view(
        (await rootBundle.load('assets/images/tray_icon.png')).buffer),
  );

  dropChannel.setFrame(
    Rect.fromCenter(
      center: await dropChannel.center(),
      width: AppSizes.pin.width,
      height: AppSizes.pin.height,
    ),
    animate: false,
  );

  runApp(const MainApp());
}

void initCli() {
  cli.setup(
    onProgress: (step, progress) {
      logger.log('Setup progress: $step ($progress)');
      setupProgress.value = progress;
      setupStep.value = step;
    },
    onError: (error) {
      logger.log('Setup error: $error');
      setupSuccess.value = false;
    },
    onSuccess: () {
      logger.log('Setup completed');
      setupSuccess.value = true;
    },
  );
}

class _UpdaterListener extends UpdaterListener {
  @override
  void onUpdaterCheckingForUpdate(appcast) {
    isCheckingForUpdate.value = true;
    updateError.value = null;
  }

  @override 
  void onUpdaterUpdateAvailable(item) {
    isCheckingForUpdate.value = false;
    updateAvailable.value = true;
    updateVersion.value = item?.versionString;
  }

  @override
  void onUpdaterUpdateNotAvailable(error) {
    isCheckingForUpdate.value = false;
    updateAvailable.value = false;
  }

  @override
  void onUpdaterError(error) {
    isCheckingForUpdate.value = false;
    updateError.value = error?.message;
  }

  @override
  void onUpdaterUpdateDownloaded(item) {
    // Handle download complete
  }

  @override
  void onUpdaterBeforeQuitForUpdate(item) {
    // Handle before quit
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      debugShowCheckedModeBanner: false,
      home: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: MacosTheme.brightnessOf(context).isDark
                ? Colors.white.withValues(alpha: .2)
                : Colors.black.withValues(alpha: .05),
            width: 1,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(32)),
        ),
        child: ListenableBuilder(
            listenable: Listenable.merge([
              setupProgress,
              setupStep,
              setupSuccess,
            ]),
            builder: (context, child) {
              if (setupSuccess() == null) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 40,
                      child: setupProgress() == 0
                          ? const Center(child: ProgressCircle())
                          : Center(
                              child: ProgressBar(value: setupProgress() * 100)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: MacosTheme.brightnessOf(context).isDark
                              ? Colors.white.withValues(alpha: .2)
                              : Colors.black.withValues(alpha: .05),
                          width: 1,
                        ),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                        color: MacosTheme.brightnessOf(context).isDark
                            ? Colors.white.withValues(alpha: .1)
                            : Colors.black.withValues(alpha: .05),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        setupStep().isEmpty
                            ? 'Checking requirements...'
                            : setupStep(),
                        style: TextStyle(
                          fontSize: 12,
                          color: MacosColors.labelColor.resolvedColor(context),
                        ),
                      ),
                    ),
                  ],
                );
              }
              if (setupSuccess() == false) {
                return Column(
                  spacing: 8,
                  children: [
                    const Text('An error occurred while setting up.'),
                    GlassButton(
                      child: const Text('Try Again'),
                      onTap: () {
                        initCli();
                      },
                    )
                  ],
                );
              }
              return const MainDropApp();
            }),
      ),
    );
  }
}
