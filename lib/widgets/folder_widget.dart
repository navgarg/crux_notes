import 'package:flutter/material.dart';

import '../models/folder_item.dart';

class FolderWidget extends StatelessWidget {
  final FolderItem folder;
  final VoidCallback? onTap;

  const FolderWidget({super.key, required this.folder, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: folder.width,
        height: folder.height,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.brown.shade300,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder, size: 40, color: Colors.brown.shade700),
            const SizedBox(height: 8),
            Text(
              folder.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.brown.shade900, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}