import 'package:flutter/material.dart';

import '../models/board_item.dart';
import '../models/note_item.dart';

class NoteWidget extends StatelessWidget {
  final NoteItem note;
  final VoidCallback? onTap;

  const NoteWidget({super.key, required this.note, this.onTap});

  @override
  Widget build(BuildContext context) {
    // This is what will be shown while dragging
    final feedbackWidget = Material(
      elevation: 4.0,
      color: Colors.transparent, // So only the container shadow is visible
      child: Container(
        width: note.width,
        height: note.height,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: note.color.withAlpha((255 * 0.8).round()), // Slightly transparent while dragging
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          note.content,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: note.color.computeLuminance() > 0.5 ? Colors.black.withAlpha((255 * 0.8).round()) : Colors.white.withAlpha((255 * 0.8).round()),
          ),
        ),
      ),
    );

    // This is the widget that stays in place when dragging starts (childWhenDragging)
    final childWhenDraggingWidget = Container(
      width: note.width,
      height: note.height,
      decoration: BoxDecoration(
          color: note.color.withAlpha((255 * 0.3).round()), // Dimmed appearance
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid)
      ),
    );

    return Draggable<BoardItem>(
      data: note,
      feedback: feedbackWidget, // Widget shown under the finger while dragging
      childWhenDragging: childWhenDraggingWidget, // Widget left behind at original spot
      onDragStarted: () {
        print('Drag started on ${note.id}');
      },
      onDragEnd: (details) {
        print('Drag ended for ${note.id}. Dropped at offset: ${details.offset}, velocity: ${details.velocity}');
      },
      child: GestureDetector( // The actual widget that is displayed and can be tapped
        onTap: onTap,
        // onLongPress: () { /* Could initiate drag or selection mode */ },
        child: Container(
          width: note.width,
          height: note.height,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: note.color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.2).round()),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Text(
            note.content,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: note.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}