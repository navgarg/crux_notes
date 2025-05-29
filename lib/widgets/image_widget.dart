import 'package:flutter/material.dart';

import '../models/board_item.dart';
import '../models/image_item.dart';

class ImageWidget extends StatelessWidget {
  final ImageItem imageItem;
  final VoidCallback? onTap;

  const ImageWidget({super.key, required this.imageItem, this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageContent = Image.network(
      imageItem.imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
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

    return Draggable<BoardItem>(
      data: imageItem,
      feedback: feedbackWidget,
      childWhenDragging: childWhenDraggingWidget,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: imageItem.width,
          height: imageItem.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha((255 * 0.2).round()), blurRadius: 4, offset: const Offset(2, 2)),
            ],
          ),
          child: imageContent,
        ),
      ),
    );
  }
}