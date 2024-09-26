import 'package:flutter/services.dart';

typedef ShakeDetectedCallback = void Function(double x, double y);
typedef DraggingSessionEndedCallback = void Function(int operation);
typedef MenuItemClickedCallback = void Function(int tag);
typedef ConcludeCallback = void Function();

class DropChannel {
  static const MethodChannel _channel =
      MethodChannel('click.shakepin.macos/drop');

  static ShakeDetectedCallback? _onShakeDetected;
  static DraggingSessionEndedCallback? _onDraggingSessionEnded;
  static MenuItemClickedCallback? _onMenuItemClicked;
  static ConcludeCallback? _onConclude;

  static Future<void> cleanup() async {
    await _channel.invokeMethod('cleanup');
  }

  static Future<void> setTrayIcon(Uint8List iconData) async {
    await _channel.invokeMethod('setTrayIcon', iconData);
  }

  static Future<void> hide() async {
    await _channel.invokeMethod('hide');
  }

  static Future<void> performDragWindow() async {
    await _channel.invokeMethod('performDragWindow');
  }

  static Future<void> performDragSession(List<String> fileURLs) async {
    await _channel.invokeMethod('performDragSession', fileURLs);
  }

  static Future<Uint8List> getFileIcon(String path) async {
    return await _channel.invokeMethod('getFileIcon', path);
  }

  static Future<void> setFrame(Rect rect,
      {bool? animate, bool? usePosition, bool? useSize}) async {
    await _channel.invokeMethod('setFrame', [
      usePosition != null ? rect.left : null,
      usePosition != null ? rect.top : null,
      useSize != null ? rect.width : null,
      useSize != null ? rect.height : null,
      animate,
    ]);
  }

  static Future<void> setMinimumSize(Size size) async {
    await _channel.invokeMethod('setMinimumSize', [size.width, size.height]);
  }

  static Future<void> setVisible(bool visible) async {
    await _channel.invokeMethod('setVisible', visible);
  }

  static Future<void> orderFront() async {
    await _channel.invokeMethod('orderFront');
  }

  static Future<void> removeDropTarget(String label) async {
    await _channel.invokeMethod('removeDropTarget', [label]);
  }

  static Future<void> setDropTarget(Rect rect, String label) async {
    await _channel.invokeMethod(
        'setDropTarget', [rect.left, rect.top, rect.width, rect.height, label]);
  }

  static Future<bool> isVisible() async {
    return await _channel.invokeMethod('isVisible');
  }

  static Future<List<double>> center() async {
    return await _channel.invokeMethod('center');
  }

  static Future<bool> convertToPng(String inputPath, String outputPath) async {
    return await _channel.invokeMethod('convertToPng', [inputPath, outputPath]);
  }

  static void setMethodCallHandler(
      Future<dynamic> Function(MethodCall call) handler) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'shakeDetected':
          final List<double> args = call.arguments.cast<double>();
          _onShakeDetected?.call(args[0], args[1]);
          break;
        case 'draggingSessionEnded':
          final int operation = call.arguments;
          _onDraggingSessionEnded?.call(operation);
          break;
        case 'menuItemClicked':
          final int tag = call.arguments;
          _onMenuItemClicked?.call(tag);
          break;
        case 'conclude':
          _onConclude?.call();
          break;
        case 'dragEnter':
          final List<double> args = call.arguments.cast<double>();
          _onDragEnter?.call(Offset(args[0], args[1]));
          break;
        case 'dragExited':
          _onDragExited?.call();
          break;
        case 'dragConclude':
          _onDragConclude?.call();
          break;
        case 'dragPerform':
          final List<String> paths = call.arguments.cast<String>();
          _onDragPerform?.call(paths);
          break;
        default:
          return handler(call);
      }
    });
  }
}

enum DropOperation {
  move,
  copy,
  link,
}

mixin class DropListener {
  String label = '';

  void onDragEnter(Offset position) {}
  void onDragExited() {}
  void onDragConclude() {}
  void onDragPerform(List<String> paths) {}
}
