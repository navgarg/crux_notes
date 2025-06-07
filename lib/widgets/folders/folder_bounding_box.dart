import 'package:flutter/material.dart';

class FolderBoundingBoxWidget extends StatelessWidget {
  final Rect rect; // The calculated rectangle for the bounding box

  const FolderBoundingBoxWidget({
    Key? key,
    required this.rect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("FolderBoundingBoxWidget building with rect: $rect (width: ${rect.width}, height: ${rect.height})");

    final bool isValidRect = rect.left.isFinite &&
        rect.top.isFinite &&
        rect.width.isFinite &&
        rect.width >= 0 && // Width cannot be negative
        rect.height.isFinite &&
        rect.height >= 0; // Height cannot be negative

    if (!isValidRect) {
      print("FolderBoundingBoxWidget: INVALID RECT received: $rect");
      return const SizedBox.shrink();
    }


    return IgnorePointer( // So it doesn't block interactions with items underneath
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
      // ),
    );
  }
}