import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shakepin/utils/logger.dart';

class CustomDragGesture extends StatefulWidget {
  const CustomDragGesture(
      {super.key, required this.child, required this.onDragStart});

  final Widget child;
  final void Function() onDragStart;

  @override
  State<CustomDragGesture> createState() => _CustomDragGestureState();
}

class _CustomDragGestureState extends State<CustomDragGesture> {
  var isTapped = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) {
        if (isTapped) return;
        logger.log('onPointerMove: ${event.kind}');
        if (event.kind == PointerDeviceKind.mouse) {
          isTapped = true;
          logger.log('Mouse drag started');
          widget.onDragStart();
        }
      },
      onPointerUp: (event) {
        logger.log('onPointerUp');
        isTapped = false;
      },
      onPointerCancel: (event) {
        logger.log('onPointerCancel');
        isTapped = false;
      },
      child: widget.child,
    );
  }
}
