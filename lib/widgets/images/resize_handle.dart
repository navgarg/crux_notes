import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/image_item.dart';
import '../../providers/board_providers.dart';

enum ResizeCorner { topLeft, topRight, bottomLeft, bottomRight }

const double _visualHandleSize = 40.0;
const double _interactiveHandleAreaSize = 80.0;
const double _minImageSize = 60.0; // Minimum width/height for an image

//todo: change shape of cursor to 4 pointer to show image is movable.
//todo: cursor should be a pointer only in the region where image is resizable.
class ResizeHandleWidget extends ConsumerStatefulWidget {
  final ImageItem imageItem;
  final ResizeCorner corner;

  const ResizeHandleWidget({
    super.key,
    required this.imageItem,
    required this.corner,
  });

  static double get visualHandleSize => _visualHandleSize;
  static double get interactiveHandleAreaSize => _interactiveHandleAreaSize;

  @override
  ConsumerState<ResizeHandleWidget> createState() => _ResizeHandleWidgetState();
}

class _ResizeHandleWidgetState extends ConsumerState<ResizeHandleWidget> {
  bool _isHandleHovering = false;

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    switch (widget.corner) {
      case ResizeCorner.topLeft:
        iconData = Icons.north_west;
        break;
      case ResizeCorner.topRight:
        iconData = Icons.north_east;
        break;
      case ResizeCorner.bottomLeft:
        iconData = Icons.south_west;
        break;
      case ResizeCorner.bottomRight:
        iconData = Icons.south_east;
        break;
    }
    final double positionOffset = -_interactiveHandleAreaSize / 2;

    // return Positioned(
        // left: (widget.corner == ResizeCorner.topLeft || widget.corner == ResizeCorner.bottomLeft) ? positionOffset : null,
        // top: (widget.corner == ResizeCorner.topLeft || widget.corner == ResizeCorner.topRight) ? positionOffset : null,
        // right: (widget.corner == ResizeCorner.topRight || widget.corner == ResizeCorner.bottomRight) ? positionOffset : null,
        // bottom: (widget.corner == ResizeCorner.bottomLeft || widget.corner == ResizeCorner.bottomRight) ? positionOffset : null,
      return MouseRegion(
        onEnter: (_) {
          // print("Enter ${widget.corner}");
          if (!_isHandleHovering) setState(() => _isHandleHovering = true);
        },
        onExit: (_) {
          // print("Exit ${widget.corner}");
          if (_isHandleHovering) setState(() => _isHandleHovering = false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details) {
            ref
                .read(boardNotifierProvider.notifier)
                .bringToFront(widget.imageItem.id);
          },
          onPanUpdate: (details) {
            double currentX = widget.imageItem.x;
            double currentY = widget.imageItem.y;
            double currentWidth = widget.imageItem.width;
            double currentHeight = widget.imageItem.height;
            double newX = currentX,
                newY = currentY,
                newWidth = currentWidth,
                newHeight = currentHeight;

            switch (widget.corner) {
              case ResizeCorner.topLeft:
                newWidth = (currentWidth - details.delta.dx).clamp(
                  _minImageSize,
                  double.infinity,
                );
                newHeight = (currentHeight - details.delta.dy).clamp(
                  _minImageSize,
                  double.infinity,
                );
                if (newWidth != currentWidth)
                  newX = currentX + (currentWidth - newWidth);
                if (newHeight != currentHeight)
                  newY = currentY + (currentHeight - newHeight);
                break;
              case ResizeCorner.topRight:
                newWidth = (currentWidth + details.delta.dx).clamp(
                  _minImageSize,
                  double.infinity,
                );
                newHeight = (currentHeight - details.delta.dy).clamp(
                  _minImageSize,
                  double.infinity,
                );
                if (newHeight != currentHeight)
                  newY = currentY + (currentHeight - newHeight);
                break;
              case ResizeCorner.bottomLeft:
                newWidth = (currentWidth - details.delta.dx).clamp(
                  _minImageSize,
                  double.infinity,
                );
                newHeight = (currentHeight + details.delta.dy).clamp(
                  _minImageSize,
                  double.infinity,
                );
                if (newWidth != currentWidth)
                  newX = currentX + (currentWidth - newWidth);
                break;
              case ResizeCorner.bottomRight:
                newWidth = (currentWidth + details.delta.dx).clamp(
                  _minImageSize,
                  double.infinity,
                );
                newHeight = (currentHeight + details.delta.dy).clamp(
                  _minImageSize,
                  double.infinity,
                );
                break;
            }

            final boardNotifier = ref.read(boardNotifierProvider.notifier);
            boardNotifier.updateItemGeometricProperties(
              widget.imageItem.id,
              newX: (newX != currentX) ? newX : null,
              newY: (newY != currentY) ? newY : null,
              newWidth: (newWidth != currentWidth) ? newWidth : null,
              newHeight: (newHeight != currentHeight) ? newHeight : null,
            );
          },
          onPanEnd: (details) {
            print(
              'Image resize pan ended for ${widget.imageItem.id} from ${widget.corner}',
            );
          },
            child: Container(
              width: _interactiveHandleAreaSize,
              height: _interactiveHandleAreaSize,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: AnimatedOpacity(
                opacity: _isHandleHovering ? 1.0 : 0,
                duration: const Duration(milliseconds: 100),
                  child: Icon(
                    iconData,
                    size: _visualHandleSize * 0.6,
                    color: Colors.grey.shade500, //todo: Change wrt theme
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha((255 * 0.3).round()),
                        offset: Offset(1, 1),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                ),
              // ),
            // ),
          ),
        ),
      // ),
    );
  }
}
