import 'package:crux_notes/widgets/resize_handle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_item.dart';
import '../models/image_item.dart';
import '../providers/board_providers.dart';

class ImageWidget extends ConsumerStatefulWidget {
  final ImageItem imageItem;

  const ImageWidget({super.key, required this.imageItem});

  @override
  ConsumerState<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends ConsumerState<ImageWidget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // final selectedIds = ref.watch(
    //   boardNotifierProvider.select((asyncValue) {
    //     return ref.read(boardNotifierProvider.notifier).selectedItemIds;
    //   }),
    // );

    final boardState = ref.watch(boardNotifierProvider);
    final Set<String> currentSelectedIds = boardState.hasValue
        ? ref.read(boardNotifierProvider.notifier).selectedItemIds
        : const {};
    final isSelected = currentSelectedIds.contains(widget.imageItem.id);

    final imageContent = FittedBox(
      fit: BoxFit.cover,
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
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
        errorBuilder:
            (BuildContext context, Object exception, StackTrace? stackTrace) {
              return const Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              );
            },
      ),
    );

    // final feedbackWidget = Material(
    //   elevation: 4.0,
    //   color: Colors.transparent,
    //   child: Container(
    //     width: widget.imageItem.width,
    //     height: widget.imageItem.height,
    //     clipBehavior: Clip.antiAlias,
    //     decoration: BoxDecoration(
    //       border: Border.all(color: Colors.grey.withAlpha((255 * 0.8).round())),
    //     ),
    //     child: Opacity(opacity: 0.8, child: imageContent),
    //   ),
    // );
    //
    // final childWhenDraggingWidget = Container(
    //   width: widget.imageItem.width,
    //   height: widget.imageItem.height,
    //   decoration: BoxDecoration(
    //     border: Border.all(
    //       color: Colors.grey.shade400,
    //       style: BorderStyle.solid,
    //     ),
    //     color: Colors.grey.withAlpha((255 * 0.1).round()),
    //   ),
    // );

    final feedbackWidget = Material(
      // Still need Material for elevation if Draggable is used
      elevation: 4.0,
      color: Colors.transparent,
      child: Container(
        width: widget.imageItem.width,
        height: widget.imageItem.height,
        decoration: BoxDecoration(
          color: Colors.blueGrey.withAlpha(150), // Simple solid color
          border: Border.all(color: Colors.grey),
        ),
        child: const Center(
          child: Text(
            "Dragging...",
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ), // No image
      ),
    );

    final childWhenDraggingWidget = Container(
      width: widget.imageItem.width,
      height: widget.imageItem.height,
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(50), // Simple solid color
        border: Border.all(color: Colors.grey.shade300),
      ),
      // No image
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Draggable<BoardItem>(
        // Main Draggable for moving the item
        data: widget.imageItem,
        feedback: feedbackWidget,
        childWhenDragging: childWhenDraggingWidget,
        dragAnchorStrategy: childDragAnchorStrategy, //todo: check??
        onDragStarted: () {
          // final notifier = ref.read(boardNotifierProvider.notifier);
          // if (!isSelected) {
          //   notifier.clearSelection();
          //   notifier.toggleItemSelection(widget.imageItem.id);
          // }
          // ref.read(boardNotifierProvider.notifier).bringToFront(widget.imageItem.id);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final notifier = ref.read(boardNotifierProvider.notifier);
                // Future.delayed(Duration.zero, () { notifier.bringToFront(widget.imageItem.id); });
                // notifier.bringToFront(widget.imageItem.id);
                // if (notifier.selectedItemIds.isNotEmpty) {
                //   notifier.toggleItemSelection(widget.imageItem.id);
                // } else {
                //   // No items selected, tap selects this one
                  notifier.toggleItemSelection(widget.imageItem.id);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    notifier.bringToFront(widget.imageItem.id);
                  }
                });
                // }
              },
              onLongPress: () {
                final notifier = ref.read(boardNotifierProvider.notifier);
                // Future.delayed(Duration.zero, () { notifier.bringToFront(widget.imageItem.id); });
                // notifier.bringToFront(widget.imageItem.id);
                notifier.toggleItemSelection(widget.imageItem.id);
              },
              child: Container(
                // The image itself
                width: widget.imageItem.width,
                height: widget.imageItem.height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(
                    // Modified border
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (_isHovering
                              ? Theme.of(context).colorScheme.primary.withAlpha(
                                  (255 * 0.7).round(),
                                )
                              : Colors.grey.shade600),
                    // width: isSelected ? 2.5 : (_isHovering ? 1.5 : 1),
                    width: 2.5,
                  ),
                ),
                child: imageContent,
              ),
            ),
            ResizeHandleWidget(
              imageItem: widget.imageItem,
              corner: ResizeCorner.topLeft,
            ),
            ResizeHandleWidget(
              imageItem: widget.imageItem,
              corner: ResizeCorner.topRight,
            ),
            ResizeHandleWidget(
              imageItem: widget.imageItem,
              corner: ResizeCorner.bottomLeft,
            ),
            ResizeHandleWidget(
              imageItem: widget.imageItem,
              corner: ResizeCorner.bottomRight,
            ),
          ],
        ),
      ),
    );
  }
}
