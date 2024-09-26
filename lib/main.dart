import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/base_app.dart';
import 'package:shakepin/utils/drop_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  dropChannel.cleanup();
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
