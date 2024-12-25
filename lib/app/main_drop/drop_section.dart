import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/dropped_item.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_target.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class DropSection extends StatefulWidget {
  const DropSection({super.key});

  @override
  State<DropSection> createState() => _DropSectionState();
}

class _DropSectionState extends State<DropSection> {
  bool _isHoveredWithItem = false;
  bool _isHoveredItem = false;
  Set<String> _selectedItems = {};

  @override
  void initState() {
    init();
    super.initState();
  }

  void init() async {
    dropChannel.setMinimumSize(AppSizes.main);
    final rect = Rect.fromCenter(
      center: await dropChannel.center(),
      width: AppSizes.main.width,
      height: AppSizes.main.height,
    );
    dropChannel.setFrame(rect, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    const maxRowItemLength = 3;

    return DropTarget(
      label: 'main-drop-app',
      onDragEnter: (details) {
        setState(() {
          _isHoveredWithItem = true;
        });
      },
      onDragExited: () {
        setState(() {
          _isHoveredWithItem = false;
        });
      },
      onDragConclude: () {
        dropChannel.hidePopover();
        setState(() {
          _isHoveredWithItem = false;
        });
      },
      onDragPerform: (paths) async {
        items.value = items().union(paths.toSet());
      },
      child: SizedBox(
        // width: AppSizes.main.height - 8,
        width: MediaQuery.sizeOf(context).width - 64,
        // width: max(
        //   AppSizes.main.width,
        //   MediaQuery.sizeOf(context).width - 16,
        // ),
        height: MediaQuery.sizeOf(context).height - 16,
        child: AnimatedContainer(
          duration: Durations.long2,
          curve: Curves.fastEaseInToSlowEaseOut,
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              color: _isHoveredWithItem
                  ? MacosColors.controlAccentColor
                  : items().isNotEmpty
                      ? MacosColors.controlColor.resolvedColor(context)
                      : MacosColors.transparent,
              width: _isHoveredWithItem ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: _isHoveredWithItem
                ? MacosColors.controlAccentColor.withOpacity(0.1)
                : items().isNotEmpty
                    ? MacosColors.controlColor
                        .resolvedColor(context)
                        .withOpacity(.05)
                    : MacosColors.controlColor
                        .resolvedColor(context)
                        .withOpacity(.1),
          ),
          child: ListenableBuilder(
              listenable: items,
              builder: (context, child) {
                if (items().isNotEmpty) {
                  return SuperListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: (items().length / maxRowItemLength).ceil(),
                    itemBuilder: (context, rowIndex) {
                      final startIndex = rowIndex * maxRowItemLength;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          spacing: 4,
                          children: List.generate(maxRowItemLength, (index) {
                            final itemIndex = startIndex + index;
                        
                            if (itemIndex < items().length) {
                              final path = items().elementAt(itemIndex);
                              final isSelected = _selectedItems.contains(path);
                              return Expanded(
                                child: DroppedItem(
                                  onEnter: () {
                                    setState(() {
                                      _isHoveredItem = true;
                                    });
                                  },
                                  onExit: () {
                                    setState(() {
                                      _isHoveredItem = false;
                                    });
                                  },
                                  onRemove: () {
                                    items.remove(path);
                                  },
                                  path: path,
                                  isSelected: isSelected,
                                  onToggleSelection: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedItems.remove(path);
                                      } else {
                                        _selectedItems.add(path);
                                      }
                                    });
                                  },
                                  isHoveredItem: _isHoveredItem,
                                ),
                              );
                            } else {
                              return const Expanded(child: SizedBox.shrink());
                            }
                          }),
                        ),
                      );
                    },
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: Durations.long2,
                      curve: Curves.fastEaseInToSlowEaseOut,
                      style: TextStyle(
                        color: _isHoveredWithItem
                            ? MacosColors.controlAccentColor
                            : MacosColors.labelColor.resolvedColor(context),
                      ),
                      child: const Text('Drop files here'),
                    ),
                  ),
                );
              }),
        ),
      ),
    );
  }
}
