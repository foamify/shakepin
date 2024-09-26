import 'package:flutter/services.dart';

typedef ShakeDetectedCallback = void Function(double x, double y);
typedef DraggingSessionEndedCallback = void Function(int operation);
typedef MenuItemClickedCallback = void Function(int tag);
typedef ConcludeCallback = void Function();

const MethodChannel _channel = MethodChannel('click.shakepin.macos/drop');

final dropChannel = DropChannel._();

class DropChannel {
  DropChannel._() {
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
          final List<dynamic> args = call.arguments;
          listeners
              .firstWhere((element) => element.label == args[0])
              .onDragEnter(Offset(args[1] as double, args[2] as double));
          break;
        case 'dragExited':
          listeners
              .firstWhere((element) => element.label == call.arguments)
              .onDragExited();
          break;
        case 'dragConclude':
          for (var element in listeners) {
            element.onDragConclude();
          }
          break;
        case 'dragPerform':
          final List<dynamic> args = call.arguments;
          listeners
              .firstWhere((element) => element.label == args[0])
              .onDragPerform(List<String>.from(args[1]));
          break;
        case 'dragUpdated':
          final List<dynamic> args = call.arguments;
          listeners
              .firstWhere((element) => element.label == args[0])
              .onDraggingUpdated(Offset(args[1] as double, args[2] as double));
          break;
        default:
          print('DropChannel: unknown method ${call.method}');
      }
    });
  }
  final listeners = <DropListener>[];

  ShakeDetectedCallback? _onShakeDetected;
  DraggingSessionEndedCallback? _onDraggingSessionEnded;
  MenuItemClickedCallback? _onMenuItemClicked;
  ConcludeCallback? _onConclude;

  Future<void> cleanup() async {
    await _channel.invokeMethod('cleanup');
  }

  Future<void> setTrayIcon(Uint8List iconData) async {
    await _channel.invokeMethod('setTrayIcon', iconData);
  }

  Future<void> hide() async {
    await _channel.invokeMethod('hide');
  }

  Future<void> performDragWindow() async {
    await _channel.invokeMethod('performDragWindow');
  }

  Future<void> performDragSession(List<String> fileURLs) async {
    await _channel.invokeMethod('performDragSession', fileURLs);
  }

  Future<Uint8List> getFileIcon(String path) async {
    return await _channel.invokeMethod('getFileIcon', path);
  }

  Future<void> setFrame(Rect rect,
      {bool? animate, bool? usePosition, bool? useSize}) async {
    await _channel.invokeMethod('setFrame', [
      usePosition != null ? rect.left : null,
      usePosition != null ? rect.top : null,
      useSize != null ? rect.width : null,
      useSize != null ? rect.height : null,
      animate,
    ]);
  }

  Future<void> setMinimumSize(Size size) async {
    await _channel.invokeMethod('setMinimumSize', [size.width, size.height]);
  }

  Future<void> setVisible(bool visible) async {
    await _channel.invokeMethod('setVisible', visible);
  }

  Future<void> orderFront() async {
    await _channel.invokeMethod('orderFront');
  }

  Future<void> removeDropTarget(String label) async {
    await _channel.invokeMethod('removeDropTarget', [label]);
  }

  Future<void> setDropTarget(Rect rect, String label) async {
    await _channel.invokeMethod(
        'setDropTarget', [rect.left, rect.top, rect.width, rect.height, label]);
  }

  Future<bool> isVisible() async {
    return await _channel.invokeMethod('isVisible');
  }

  Future<List<double>> center() async {
    return await _channel.invokeMethod('center');
  }

  Future<bool> convertToPng(String inputPath, String outputPath) async {
    return await _channel.invokeMethod('convertToPng', [inputPath, outputPath]);
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
  void onDraggingUpdated(Offset position) {}
  void onDragPerform(List<String> paths) {}
}
