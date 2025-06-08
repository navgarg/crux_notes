import 'dart:math';

import 'package:crux_notes/widgets/images/resize_handle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/board_item.dart';
import '../../models/image_item.dart';
import '../../models/note_item.dart';
import '../../providers/board_providers.dart';

class ImageWidget extends ConsumerStatefulWidget {
  final ImageItem imageItem;

  const ImageWidget({super.key, required this.imageItem});

  @override
  ConsumerState<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends ConsumerState<ImageWidget> {
  bool _isHovering = false;
  bool _isCurrentlyResizing = false;

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(boardNotifierProvider);
    final Set<String> selectedIds = boardState.hasValue
        ? ref.read(boardNotifierProvider.notifier).selectedItemIds
        : const {};
    final isSelected = selectedIds.contains(widget.imageItem.id);

    final imageContent = FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        widget.imageItem.imageUrl,
        key: ValueKey(widget.imageItem.imageUrl),
        fit: BoxFit.cover,
        loadingBuilder:
            (
              BuildContext context,
              Widget child,
              ImageChunkEvent? loadingProgress,
            ) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: widget.imageItem.width - 10,
                height: widget.imageItem.height - 10,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
        errorBuilder:
            (BuildContext context, Object exception, StackTrace? stackTrace) {
              return SizedBox(
                // Constrain the error icon
                width: widget.imageItem.width,
                height: widget.imageItem.height,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                ),
              );
            },
      ),
    );

    final feedbackWidget = Material(
      elevation: 4.0,
      color: Colors.transparent,
      child: Container(
        width: widget.imageItem.width,
        height: widget.imageItem.height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withAlpha(150), width: 1.0),
        ),
        child: Opacity(opacity: 0.75, child: imageContent),
      ),
    );

    final childWhenDraggingWidget = Container(
      width: widget.imageItem.width,
      height: widget.imageItem.height,
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade400,
          style: BorderStyle.solid,
        ),
      ),
    );

    Widget imageDisplayWithHandles = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: _isCurrentlyResizing
          ? SystemMouseCursors.resizeUpLeftDownRight
          : SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTap: () {
          if (_isCurrentlyResizing) return;
          final notifier = ref.read(boardNotifierProvider.notifier);
          notifier.toggleItemSelection(widget.imageItem.id);
        },
        onLongPress: () {
          if (_isCurrentlyResizing) return;
          ref
              .read(boardNotifierProvider.notifier)
              .toggleItemSelection(widget.imageItem.id);
        },
        child: SizedBox(
          // Constrains the Stack
          width: widget.imageItem.width,
          height: widget.imageItem.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                // Main image container
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : (_isHovering || _isCurrentlyResizing
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(180)
                                : Colors.grey.shade600),
                      width: isSelected
                          ? 4
                          : (_isHovering || _isCurrentlyResizing ? 1.5 : 1),
                    ),
                  ),
                  child: imageContent,
                ),
              ),
              // Conditionally display Resize Handles
              if (_isHovering ||
                  isSelected ||
                  _isCurrentlyResizing) // Show if hovered, selected, OR resizing
                ...ResizeCorner.values.map((corner) {
                  return Positioned(
                    // Calculate position for each corner handle (ensure ResizeHandleWidget.getInteractiveHandleAreaSize is accessible)
                    left:
                        (corner == ResizeCorner.topLeft ||
                            corner == ResizeCorner.bottomLeft)
                        ? (-ResizeHandleWidget.interactiveHandleAreaSize / 2 +
                              ResizeHandleWidget.visualHandleSize / 4)
                        : null,
                    top:
                        (corner == ResizeCorner.topLeft ||
                            corner == ResizeCorner.topRight)
                        ? (-ResizeHandleWidget.interactiveHandleAreaSize / 2 +
                              ResizeHandleWidget.visualHandleSize / 4)
                        : null,
                    right:
                        (corner == ResizeCorner.topRight ||
                            corner == ResizeCorner.bottomRight)
                        ? (-ResizeHandleWidget.interactiveHandleAreaSize / 2 +
                              ResizeHandleWidget.visualHandleSize / 4)
                        : null,
                    bottom:
                        (corner == ResizeCorner.bottomLeft ||
                            corner == ResizeCorner.bottomRight)
                        ? (-ResizeHandleWidget.interactiveHandleAreaSize / 2 +
                              ResizeHandleWidget.visualHandleSize / 4)
                        : null,
                    width: ResizeHandleWidget.interactiveHandleAreaSize,
                    height: ResizeHandleWidget.interactiveHandleAreaSize,
                    child: Listener(
                      // Listener to manage _isCurrentlyResizing state for the parent ImageWidget
                      onPointerDown: (event) {
                        setState(() => _isCurrentlyResizing = true);
                        ref
                            .read(boardNotifierProvider.notifier)
                            .bringToFront(widget.imageItem.id);
                      },
                      onPointerUp: (event) {
                        setState(() => _isCurrentlyResizing = false);
                      },
                      onPointerCancel: (event) {
                        if (_isCurrentlyResizing)
                          setState(() => _isCurrentlyResizing = false);
                      },
                      child: ResizeHandleWidget(
                        key: ValueKey('${widget.imageItem.id}_handle_$corner'),
                        imageItem: widget.imageItem,
                        corner: corner,
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );

    // Draggable for moving the whole item or the selected group
    return Draggable<BoardItem>(
      data: widget.imageItem,
      feedback: feedbackWidget,
      childWhenDragging: childWhenDraggingWidget,
      onDragStarted: () {
        if (_isCurrentlyResizing) {
          print(
            "ImageWidget: Main Draggable onDragStarted called while _isCurrentlyResizing is true. This might be an issue.",
          );
          return;
        }

        print(
          "ImageWidget: Main Draggable onDragStarted for ${widget.imageItem.id} or group",
        );
        final boardNotifier = ref.read(boardNotifierProvider.notifier);
        boardNotifier.bringToFront(
          widget.imageItem.id,
        ); // Bring the physically grabbed item to front

        Set<String> selectedIdsAtDragStart = Set.from(
          boardNotifier.selectedItemIds,
        );
        bool wasThisItemAlreadySelected = selectedIdsAtDragStart.contains(
          widget.imageItem.id,
        );

        if (wasThisItemAlreadySelected && selectedIdsAtDragStart.length > 1) {
          // Case 1: The grabbed item was already part of a multi-item selection.
          // This is a group drag.
          print(
            "Draggable: Drag started on ${widget.imageItem.id} as part of existing group ${selectedIdsAtDragStart}",
          );
          selectedIdsAtDragStart.forEach((id) {
            if (id != widget.imageItem.id)
              boardNotifier.bringToFront(
                id,
              ); // Bring other group members to front too
          });
          boardNotifier.startGroupDrag(
            selectedIdsAtDragStart,
            widget.imageItem.id,
          );
        } else {
          // Case 2: The grabbed item was NOT part of a multi-item selection.
          if (!wasThisItemAlreadySelected ||
              selectedIdsAtDragStart.length > 1) {
            // If it wasn't selected OR if other items were selected (but this one wasn't leading a group)
            print(
              "Draggable: Drag started on ${widget.imageItem.id}. It now becomes the sole selected item for this drag operation.",
            );
            boardNotifier.clearSelection();
            boardNotifier.toggleItemSelection(
              widget.imageItem.id,
            ); // Selects only this item
          } else {
            // It was already the only selected item. No change to selection needed.
            print(
              "Draggable: Drag started on ${widget.imageItem.id} which was already solely selected.",
            );
          }
          // For a single item drag, ensure any previous group drag state is cleared.
          boardNotifier.endGroupDrag();
          print(
            "Draggable: ${widget.imageItem.id} is being dragged alone (not as a group leader).",
          );
        }
      },
      onDragEnd: (details) {
        if (details.wasAccepted) return; // Position updated by DragTarget

        final notifier = ref.read(boardNotifierProvider.notifier);
        print(
          "Draggable for ${widget.imageItem.id}: Drag was NOT accepted. Clearing group state.",
        );
        notifier.endGroupDrag();

        if (_isCurrentlyResizing) setState(() => _isCurrentlyResizing = false);
      },
      onDraggableCanceled: (velocity, offset) {
        if (_isCurrentlyResizing) setState(() => _isCurrentlyResizing = false);
      },
      onDragCompleted: () {
        if (_isCurrentlyResizing) setState(() => _isCurrentlyResizing = false);
      },
      child: imageDisplayWithHandles,
    );
  }
}
