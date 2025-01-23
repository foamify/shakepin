import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_target.dart';

class SideButton extends StatefulWidget {
  const SideButton({
    super.key,
    required this.child,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onDragPerform,
    required this.onShowTooltip,
    required this.onHideTooltip,
    required this.onTap,
  });

  final Widget child;
  final String label;
  final String tooltip;
  final bool selected;
  final void Function(List<String> paths) onDragPerform;
  final void Function(String tooltip) onShowTooltip;
  final void Function() onHideTooltip;
  final void Function() onTap;

  @override
  State<SideButton> createState() => _SideButtonState();
}

class _SideButtonState extends State<SideButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() {
          _isPressed = false;
          widget.onTap();
        }),
        onTapCancel: () => setState(() => _isPressed = false),
        child: DropTarget(
          label: 'side-button-${widget.label}',
          onDragEnter: (_) {
            setState(() => _isHovered = true);
            widget.onShowTooltip(widget.tooltip);
          },
          onDragExited: () {
            setState(() => _isHovered = false);
            widget.onHideTooltip();
          },
          onDragConclude: () {
            setState(() => _isHovered = false);
            widget.onHideTooltip();
          },
          onDragSessionEnded: (_) {
            setState(() => _isHovered = false);
            widget.onHideTooltip();
          },
          onDragPerform: (items) => widget.onDragPerform(items),
          child: AnimatedScale(
            scale: _isPressed ? .9 : 1,
            duration: Durations.short2,
            curve: Curves.fastEaseInToSlowEaseOut,
            child: AnimatedContainer(
              width: 48,
              height: 48,
              duration: Durations.medium4,
              curve: Curves.fastEaseInToSlowEaseOut,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isHovered
                    ? widget.selected
                        ? MacosColors.controlAccentColor.withValues(alpha:0.4)
                        : MacosColors.controlColor.resolvedColor(context)
                    : widget.selected
                        ? MacosColors.controlAccentColor.withValues(alpha:0.2)
                        : MacosColors.controlColor
                            .resolvedColor(context)
                            .withAlpha(0),
              ),
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  strokeAlign: -2.0,
                  color: widget.selected
                      ? MacosColors.controlAccentColor
                      : _isHovered
                          ? Colors.transparent
                          : MacosColors.controlColor.resolvedColor(context),
                ),
              ),
              child: AnimatedScale(
                scale: _isHovered
                    ? 1.2
                    : widget.selected
                        ? 1.1
                        : 1,
                duration: Durations.long4,
                curve: Curves.fastEaseInToSlowEaseOut,
                child: IconTheme(
                  data: IconThemeData(
                    color: widget.selected
                        ? MacosColors.controlAccentColor
                        : MacosColors.labelColor.resolveFrom(context),
                    opacity: _isHovered ? 1 : 0.8,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
