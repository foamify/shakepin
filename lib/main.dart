import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libcaesium_dart/libcaesium_dart.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/base_app.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

void main() async {
  await RustLib.init();
  WidgetsFlutterBinding.ensureInitialized();
  dropChannel.setTrayIcon(
    Uint8List.view(
        (await rootBundle.load('assets/images/tray_icon.png')).buffer),
  );

  dropChannel.setFrame(
    Rect.fromCenter(
      center: await dropChannel.center(),
      width: AppSizes.panel.width,
      height: AppSizes.panel.height,
    ),
    animate: false,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MacosApp(
      debugShowCheckedModeBanner: false,
      home: BaseApp(),
    );
  }
}
