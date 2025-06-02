import 'package:flutter/material.dart';

class FolderBoundingBoxWidget extends StatelessWidget {
  final Rect rect; // The calculated rectangle for the bounding box

  const FolderBoundingBoxWidget({
    super.key,
    required this.rect,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: key,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer( // So it doesn't block interactions with items underneath
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blueAccent.withAlpha((255*0.5).round()),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.blueAccent.withAlpha((255*0.05).round()),
          ),
        ),
      ),
    );
  }
}