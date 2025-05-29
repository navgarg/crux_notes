import 'package:flutter/material.dart';

import '../models/image_item.dart';

class ImageWidget extends StatelessWidget {
  final ImageItem imageItem;
  final VoidCallback? onTap;

  const ImageWidget({super.key, required this.imageItem, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Will be null or do nothing
      child: Container(
        width: imageItem.width,
        height: imageItem.height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Image.network(
          imageItem.imageUrl,
          fit: BoxFit.cover,
          // Basic error and loading handling
          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
            return const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
          },
        ),
      ),
    );
  }
}