import 'package:flutter/material.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/app/minify_app_oss.dart' as oss;
import 'package:shakepin/app/minify_app_store.dart' as store;

class MinifyApp extends StatelessWidget {
  const MinifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (isAppStore) {
      return const store.MinifyApp();
    } else {
      return const oss.MinifyApp();
    }
  }
}
