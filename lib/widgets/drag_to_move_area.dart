import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shakepin/utils/drop_channel.dart';

class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        if (details.kind == PointerDeviceKind.mouse) {
          dropChannel.performDragWindow();
        }
      },
      child: child,
    );
  }
}
