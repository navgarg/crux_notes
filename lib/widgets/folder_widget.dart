import 'package:flutter/material.dart';

import '../models/board_item.dart';
import '../models/folder_item.dart';

class FolderWidget extends StatelessWidget {
  final FolderItem folder;
  final VoidCallback? onTap;

  const FolderWidget({super.key, required this.folder, this.onTap});

  @override
  Widget build(BuildContext context) {
    final folderContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.folder, size: 40, color: Colors.brown.shade700),
        const SizedBox(height: 8),
        Text(
          folder.name,
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.brown.shade900, fontWeight: FontWeight.bold),
        ),
      ],
    );

    final feedbackWidget = Material(
      elevation: 4.0,
      color: Colors.transparent,
      child: Container(
        width: folder.width,
        height: folder.height,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(color: Colors.brown.shade300.withAlpha((255 * 0.8).round()), borderRadius: BorderRadius.circular(8)),
        child: folderContent,
      ),
    );

    final childWhenDraggingWidget = Container(
      width: folder.width,
      height: folder.height,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
          color: Colors.brown.shade300.withAlpha((255 * 0.3).round()),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid)
      ),
    );

    return Draggable<BoardItem>(
      data: folder,
      feedback: feedbackWidget,
      childWhenDragging: childWhenDraggingWidget,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: folder.width,
          height: folder.height,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.brown.shade300,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha((255 * 0.2).round()), blurRadius: 4, offset: const Offset(2, 2)),
            ],
          ),
          child: folderContent,
        ),
      ),
    );
  }
}