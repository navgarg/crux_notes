import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_item.dart';
import '../models/note_item.dart';
import '../providers/board_providers.dart';
import '../screens/note_editor_screen.dart';

class NoteWidget extends ConsumerWidget {
  final NoteItem note;
  final VoidCallback? onPrimaryAction;

  const NoteWidget({super.key, required this.note, this.onPrimaryAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool _isHovering = false;
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

    return Draggable<BoardItem>(
      data: note,
      feedback: feedbackWidget, // Widget shown under the finger while dragging
      childWhenDragging:
          childWhenDraggingWidget, // Widget left behind at original spot
      onDragStarted: () {
        final boardNotifier = ref.read(boardNotifierProvider.notifier);
        boardNotifier.bringToFront(note.id);
        // Store initial positions if using relative offset method
        Set<String> selectionStateForDrag = Set.from(boardNotifier.selectedItemIds);
        bool thisItemIsSelected = selectionStateForDrag.contains(note.id);

        if (thisItemIsSelected && selectionStateForDrag.length > 1) {
          // Case 1: This item is already part of a multi-selection. Start group drag.
          print("Draggable: Drag started on ${note.id} as part of existing group $selectionStateForDrag");
          selectionStateForDrag.forEach((id) {
            if (id != note.id) boardNotifier.bringToFront(id);
          });
          boardNotifier.startGroupDrag(selectionStateForDrag, note.id);
        } else {
          // Case 2: This item is not part of a multi-selection (or is dragged alone).
          // Clear any other selection and select only this item.
          // This becomes a single item drag (startGroupDrag will not be effectively called with a group).
          if (!thisItemIsSelected || selectionStateForDrag.length > 1) {
            print("Draggable: Drag started on ${note.id}. It becomes the sole selected item for this drag.");
            boardNotifier.clearSelection();
            boardNotifier.toggleItemSelection(note.id); // Ensures it's selected
          }
          boardNotifier.endGroupDrag(); // Ensure no prior group drag state is active
          print("Draggable: ${note.id} is being dragged alone.");
        }
      },
      onDragEnd: (details) {
        if (details.wasAccepted) return; // Position updated by DragTarget

        final notifier = ref.read(boardNotifierProvider.notifier);
          print("Draggable for ${note.id}: Drag was NOT accepted. Clearing group state.");
          notifier.endGroupDrag();
      },
      child: MouseRegion(
        // onEnter: (_) => setState(() => _isHovering = true),
        // onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onDoubleTap: () {
            final notifier = ref.read(boardNotifierProvider.notifier);
            notifier.bringToFront(note.id);

            // Ensure this note becomes the sole selection
            if (!(isSelected && currentSelectedIds.length == 1)) {
              notifier.clearSelection();
              notifier.toggleItemSelection(note.id);
            }

            //  flag for animation control in BoardViewWidget
            notifier.setOpeningNoteId(note.id);

            Navigator.of(context).push(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 800), //slower animation
                  pageBuilder: (context, animation, secondaryAnimation) => NoteEditorScreen(noteToEdit: note),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child); // fade for smoother feel with Hero
                  },
                )
            ).then((_) {
              // When NoteEditorScreen is popped, clear the opening note ID
              notifier.clearOpeningNoteId();
            });
          },
          onTap: () {
            final notifier = ref.read(boardNotifierProvider.notifier);
            notifier.bringToFront(note.id);
            notifier.toggleItemSelection(note.id);

          },
          child: Hero(
            tag: 'note_hero_${note.id}',
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
                  fontSize: 18,
                  color: note.color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
