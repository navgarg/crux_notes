import 'package:crux_notes/widgets/resize_handle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_item.dart';
import '../models/image_item.dart';
import '../providers/board_providers.dart';

class ImageWidget extends ConsumerWidget {
  final ImageItem imageItem;

  const ImageWidget({super.key, required this.imageItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageContent = Image.network(
      imageItem.imageUrl,
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
        width: imageItem.width,
        height: imageItem.height,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withAlpha((255 * 0.8).round()))),
        child: Opacity(opacity: 0.8, child: imageContent),
      ),
    );

    final childWhenDraggingWidget = Container(
      width: imageItem.width,
      height: imageItem.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
        color: Colors.grey.withAlpha((255 * 0.1).round()),
      ),
    );

    return Draggable<BoardItem>( // Main Draggable for moving the item
      data: imageItem,
      feedback: feedbackWidget,
      childWhenDragging: childWhenDraggingWidget,
      onDragStarted: () {
        ref.read(boardNotifierProvider.notifier).bringToFront(imageItem.id);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container( // The image itself
            width: imageItem.width,
            height: imageItem.height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withAlpha((255 * 0.8).round())),
            ),
            child: imageContent,
          ),
          ResizeHandleWidget(imageItem: imageItem, corner: ResizeCorner.topLeft),
          ResizeHandleWidget(imageItem: imageItem, corner: ResizeCorner.topRight),
          ResizeHandleWidget(imageItem: imageItem, corner: ResizeCorner.bottomLeft),
          ResizeHandleWidget(imageItem: imageItem, corner: ResizeCorner.bottomRight),
        ],
      ),
    );
  }
}