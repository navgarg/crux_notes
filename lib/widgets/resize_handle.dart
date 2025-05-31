import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/image_item.dart';
import '../providers/board_providers.dart';

enum ResizeCorner { topLeft, topRight, bottomLeft, bottomRight }

const double _resizeHandleSize = 24.0; // Size of the draggable resize handle
const double _resizeHandleHitSlop = 8.0; // Extra padding for easier grabbing
const double _minImageSize = 50.0; // Minimum width/height for an image


class ResizeHandleWidget extends ConsumerWidget {
  final ImageItem imageItem;
  final ResizeCorner corner;

  const ResizeHandleWidget({
    super.key,
    required this.imageItem,
    required this.corner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData iconData;
    switch (corner) {
      case ResizeCorner.topLeft:    iconData = Icons.north_west; break;
      case ResizeCorner.topRight:   iconData = Icons.north_east; break;
      case ResizeCorner.bottomLeft: iconData = Icons.south_west; break;
      case ResizeCorner.bottomRight:iconData = Icons.south_east; break;
    }

    return Positioned(
      left: (corner == ResizeCorner.topLeft || corner == ResizeCorner.bottomLeft) ? -_resizeHandleSize / 2 + _resizeHandleHitSlop/2 : null,
      top: (corner == ResizeCorner.topLeft || corner == ResizeCorner.topRight) ? -_resizeHandleSize / 2 + _resizeHandleHitSlop/2 : null,
      right: (corner == ResizeCorner.topRight || corner == ResizeCorner.bottomRight) ? -_resizeHandleSize / 2 + _resizeHandleHitSlop/2 : null,
      bottom: (corner == ResizeCorner.bottomLeft || corner == ResizeCorner.bottomRight) ? -_resizeHandleSize / 2 + _resizeHandleHitSlop/2 : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          ref.read(boardNotifierProvider.notifier).bringToFront(imageItem.id);
        },
        onPanUpdate: (details) {
          double currentX = imageItem.x;
          double currentY = imageItem.y;
          double currentWidth = imageItem.width;
          double currentHeight = imageItem.height;

          double newX = currentX;
          double newY = currentY;
          double newWidth = currentWidth;
          double newHeight = currentHeight;

          switch (corner) {
            case ResizeCorner.topLeft:
              newWidth = (currentWidth - details.delta.dx).clamp(_minImageSize, double.infinity);
              newHeight = (currentHeight - details.delta.dy).clamp(_minImageSize, double.infinity);
              // Only update position if size actually changed, to prevent jitter if at min size
              if (newWidth != currentWidth) newX = currentX + (currentWidth - newWidth);
              if (newHeight != currentHeight) newY = currentY + (currentHeight - newHeight);
              break;
            case ResizeCorner.topRight:
              newWidth = (currentWidth + details.delta.dx).clamp(_minImageSize, double.infinity);
              newHeight = (currentHeight - details.delta.dy).clamp(_minImageSize, double.infinity);
              if (newHeight != currentHeight) newY = currentY + (currentHeight - newHeight);
              break;
            case ResizeCorner.bottomLeft:
              newWidth = (currentWidth - details.delta.dx).clamp(_minImageSize, double.infinity);
              newHeight = (currentHeight + details.delta.dy).clamp(_minImageSize, double.infinity);
              if (newWidth != currentWidth) newX = currentX + (currentWidth - newWidth);
              break;
            case ResizeCorner.bottomRight:
              newWidth = (currentWidth + details.delta.dx).clamp(_minImageSize, double.infinity);
              newHeight = (currentHeight + details.delta.dy).clamp(_minImageSize, double.infinity);
              break;
          }

          final boardNotifier = ref.read(boardNotifierProvider.notifier);
          boardNotifier.updateItemGeometricProperties(
            imageItem.id,
            newX: (newX != currentX) ? newX : null,
            newY: (newY != currentY) ? newY : null,
            newWidth: (newWidth != currentWidth) ? newWidth : null,
            newHeight: (newHeight != currentHeight) ? newHeight : null,
          );
        },
        onPanEnd: (details) {
          print('Image resize pan ended for ${imageItem.id} from $corner');
        },
        child: Container(
          width: _resizeHandleSize + _resizeHandleHitSlop,
          height: _resizeHandleSize + _resizeHandleHitSlop,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(180),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(200), width: 1),
          ),
          child: Icon(
            iconData,
            size: _resizeHandleSize * 0.55,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}