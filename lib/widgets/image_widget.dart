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
    final imageContent = Image.network(
      widget.imageItem.imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
            child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null));
      },
      errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
        return const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
      },
    );

    final feedbackWidget = Material(
      elevation: 4.0,
      color: Colors.transparent,
      child: Container(
        width: widget.imageItem.width,
        height: widget.imageItem.height,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withAlpha((255 * 0.8).round()))),
        child: Opacity(opacity: 0.8, child: imageContent),
      ),
    );

    final childWhenDraggingWidget = Container(
      width: widget.imageItem.width,
      height: widget.imageItem.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
        color: Colors.grey.withAlpha((255 * 0.1).round()),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Draggable<BoardItem>(
        data: widget.imageItem,
        feedback: feedbackWidget,
        childWhenDragging: childWhenDraggingWidget,
        onDragStarted: () {
          ref.read(boardNotifierProvider.notifier).bringToFront(widget.imageItem.id);
        },
        onDragEnd: (details) {
          // Position is updated by the BoardScreen's DragTarget
        },
        // The main child that is displayed on the board
        child: Stack(
          clipBehavior: Clip.none, // Allow handle to be slightly outside if needed
          children: [
            Container(
              width: widget.imageItem.width,
              height: widget.imageItem.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isHovering ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
                  width: _isHovering ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 4, offset: const Offset(2, 2)),
                ],
              ),
              child: imageContent,
            ),
            // Resize Handle
            if(_isHovering)
              ...[ // Use spread operator to add multiple widgets
                ResizeHandleWidget(imageItem: widget.imageItem, corner: ResizeCorner.topLeft),
                ResizeHandleWidget(imageItem: widget.imageItem, corner: ResizeCorner.topRight),
                ResizeHandleWidget(imageItem: widget.imageItem, corner: ResizeCorner.bottomLeft),
                ResizeHandleWidget(imageItem: widget.imageItem, corner: ResizeCorner.bottomRight),
              ],
          ],
        ),
      ),
    );
  }
}