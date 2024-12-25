import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

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
        debugPrint('onPointerMove: ${event.kind}');
        if (event.kind == PointerDeviceKind.mouse) {
          isTapped = true;
          debugPrint('Mouse drag started');
          widget.onDragStart();
        }
      },
      onPointerUp: (event) {
        debugPrint('onPointerUp');
        isTapped = false;
      },
      onPointerCancel: (event) {
        debugPrint('onPointerCancel');
        isTapped = false;
      },
      child: widget.child,
    );
  }
}
