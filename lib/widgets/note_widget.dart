import 'package:flutter/material.dart';

import '../models/note_item.dart';

class NoteWidget extends StatelessWidget {
  final NoteItem note;
  final VoidCallback? onTap;

  const NoteWidget({super.key, required this.note, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: note.width,
        height: note.height,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: note.color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Text(
          note.content,
          maxLines: 5, // Show a preview
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: note.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}