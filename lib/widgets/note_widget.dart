import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_item.dart';
import '../models/note_item.dart';
import '../providers/board_providers.dart';

class NoteWidget extends ConsumerWidget {
  final NoteItem note;
  final VoidCallback? onPrimaryAction;

  const NoteWidget({super.key, required this.note, this.onPrimaryAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(boardNotifierProvider);
    final Set<String> currentSelectedIds = boardState.hasValue
        ? ref.read(boardNotifierProvider.notifier).selectedItemIds
        : const {};
    final isSelected = currentSelectedIds.contains(note.id);

    // This is what will be shown while dragging
    final feedbackWidget = Material(
      elevation: 4.0,
      color: Colors.transparent,
      child: Container(
        width: note.width,
        height: note.height,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: note.color.withAlpha(
            (255 * 0.8).round(),
          ), // Slightly transparent while dragging
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          note.content,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: note.color.computeLuminance() > 0.5
                ? Colors.black.withAlpha((255 * 0.8).round())
                : Colors.white.withAlpha((255 * 0.8).round()),
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
        border: Border.all(
          color: Colors.grey.shade400,
          style: BorderStyle.solid,
        ),
      ),
    );

    return Draggable<Object>(
      data: (currentSelectedIds.length > 1 && isSelected)
          ? currentSelectedIds // If multiple items are selected and this is one of them, drag the whole group
          : note,
      feedback: feedbackWidget, // Widget shown under the finger while dragging
      childWhenDragging:
          childWhenDraggingWidget, // Widget left behind at original spot
      onDragStarted: () {
        // if dragging an unselected item, select it and clear others.
        final notifier = ref.read(boardNotifierProvider.notifier);
        notifier.bringToFront(note.id);
        if (!isSelected) {
          notifier.clearSelection();
          notifier.toggleItemSelection(note.id);
        }
        print('Drag started on ${note.id}');
      },
      onDragEnd: (details) {
        print(
          'Drag ended for ${note.id}. Dropped at offset: ${details.offset}, velocity: ${details.velocity}',
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onDoubleTap: () {
          // If there are items already selected, tapping another toggles its selection.
          // If no items are selected, primary tap opens the editor.
          final notifier = ref.read(boardNotifierProvider.notifier);
          notifier.bringToFront(note.id);
          if (notifier.selectedItemIds.isNotEmpty && notifier.selectedItemIds.length > 1) {
            notifier.toggleItemSelection(note.id);
          } else if (isSelected && notifier.selectedItemIds.length == 1) { // Only this item is selected
            if (onPrimaryAction != null) {
              onPrimaryAction!();
            } else { // No primary action, but it's selected, so deselect it
              notifier.toggleItemSelection(note.id);
            }
          } else if (!isSelected && notifier.selectedItemIds.isEmpty) { // No items selected
            if (onPrimaryAction != null) {
              onPrimaryAction!();
            } else { // No primary action and not selected, select it
              notifier.toggleItemSelection(note.id);
            }
          } else { // Some other item is selected, and this one is not: select this one
            notifier.clearSelection(); // Clear others
            notifier.toggleItemSelection(note.id); // Select this
          }
        },
        onTap: () {
          final notifier = ref.read(boardNotifierProvider.notifier);
          notifier.bringToFront(note.id);
          notifier.toggleItemSelection(note.id);

        },
        child: Container(
          width: note.width,
          height: note.height,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: note.color,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 4)
                : Border.all(color: Colors.transparent, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.2).round()),
                blurRadius: isSelected ? 6 : 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Text(
            note.content,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: note.color.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
