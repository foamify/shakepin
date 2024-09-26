import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/base_app.dart';
import 'package:shakepin/utils/drop_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  dropChannel.cleanup();
  dropChannel.setTrayIcon(
    Uint8List.view(
        (await rootBundle.load('assets/images/tray_icon.png')).buffer),
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MacosApp(
      home: BaseApp(),
    );
  }
}
