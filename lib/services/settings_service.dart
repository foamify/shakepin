import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shakepin/utils/cli_tool_helper.dart';

class SettingsService {
  static const MethodChannel _channel = MethodChannel('click.shakepin.macos/settings');
  static final StreamController<Map<String, dynamic>> _settingsController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  static Stream<Map<String, dynamic>> get settingsStream => _settingsController.stream;
  
  static bool _initialized = false;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    
    print('[SETTINGS] SettingsService.initialize() called');
    _channel.setMethodCallHandler((call) async {
      print('[SETTINGS] _handleMethodCall called with method: "${call.method}"');
      print('[SETTINGS] call.arguments: ${call.arguments}');
      print('[SETTINGS] method == "settingChanged": ${call.method == "settingChanged"}');
      print('[SETTINGS] method.trim() == "settingChanged": ${call.method.trim() == "settingChanged"}');
      
      if (call.method.trim() == 'settingChanged') {
        final args = call.arguments as Map<String, dynamic>;
        final key = args['key'] as String;
        final value = args['value'];
        print('[SETTINGS] Setting changed - key: $key, value: $value');
        _settingsController.add({key: value});
        print('[SETTINGS] Notified listeners');
      } else if (call.method.trim() == 'openInstall') {
        // Native macOS requested to open installation guide for a tool
        try {
          final tool = call.arguments as String;
          print('[SETTINGS] openInstall called for tool: $tool');
          await CliToolHelper.openInstallationGuide(tool);
          print('[SETTINGS] openInstall completed for tool: $tool');
        } catch (e) {
          print('[SETTINGS] Failed to handle openInstall: $e');
        }
      } else {
        print('[SETTINGS] Unknown method call: ${call.method}');
      }
    });
    
    _initialized = true;
  }

  static Future<void> openSettings() async {
    print('[SETTINGS] openSettings called');
    try {
      await _channel.invokeMethod('showSettings');
      print('[SETTINGS] openSettings native call completed');
    } on PlatformException catch (e) {
      print('[SETTINGS] Failed to open settings: ${e.message}');
    }
  }
  
  static Future<T?> getSetting<T>(String key) async {
    print('[SETTINGS] getSetting called for key: $key');
    try {
      final result = await _channel.invokeMethod('getSetting', key);
      print('[SETTINGS] getSetting result for $key: $result');
      return result as T?;
    } on PlatformException catch (e) {
      print('[SETTINGS] Failed to get setting $key: ${e.message}');
      return null;
    }
  }
  
  static Future<void> setSetting(String key, dynamic value) async {
    print('[SETTINGS] setSetting called - key: $key, value: $value');
    try {
      await _channel.invokeMethod('setSetting', {'key': key, 'value': value});
      print('[SETTINGS] setSetting native call completed');
    } on PlatformException catch (e) {
      print('[SETTINGS] Failed to set setting $key: ${e.message}');
    }
  }
  
  static Future<Map<String, dynamic>?> getAllSettings() async {
    print('[SETTINGS] getAllSettings called');
    try {
      final result = await _channel.invokeMethod('getAllSettings');
      print('[SETTINGS] getAllSettings result: $result');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      print('[SETTINGS] Failed to get all settings: ${e.message}');
      return null;
    }
  }
  
  static void dispose() {
    _settingsController.close();
  }
}
