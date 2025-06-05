import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/board_item.dart';
import '../../models/folder_item.dart';
import '../../models/note_item.dart';
import '../../providers/board_providers.dart';

class FolderWidget extends ConsumerWidget {
  final FolderItem folder;
  final VoidCallback? onPrimaryAction;

  const FolderWidget({super.key, required this.folder, this.onPrimaryAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardNotifier = ref.read(boardNotifierProvider.notifier);

    final openFolderIds = ref.watch(
      boardNotifierProvider.select(
        (s) => s.valueOrNull != null
            ? boardNotifier.openFolderIds
            : const <String>{},
      ),
    );
    final isSelected = ref
        .watch(
          boardNotifierProvider.select(
            (s) => s.valueOrNull != null
                ? boardNotifier.selectedItemIds
                : const <String>{},
          ),
        )
        .contains(folder.id);

    final bool isOpen = openFolderIds.contains(folder.id);

    final folderContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isOpen ? Icons.folder_open : Icons.folder,
          size: 40,
          color: Colors.brown.shade700,
        ),
        const SizedBox(height: 8),
        Text(
          folder.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.brown.shade900,
            fontWeight: FontWeight.bold,
          ),
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
        decoration: BoxDecoration(
          color: Colors.brown.shade300.withAlpha((255 * 0.8).round()),
          borderRadius: BorderRadius.circular(8),
        ),
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
        border: Border.all(
          color: Colors.grey.shade400,
          style: BorderStyle.solid,
        ),
      ),
    );

    if (isOpen) {
      // If folder is open, it's not a drop target itself (bounding box is)
      return Draggable<BoardItem>(
        data: folder,
        feedback: feedbackWidget,
        childWhenDragging:
            childWhenDraggingWidget,
        onDragStarted: () {
          boardNotifier.bringToFront(folder.id);
          if (!isSelected) {
            boardNotifier.clearSelection();
            boardNotifier.toggleItemSelection(folder.id);
          }
        },
        child: GestureDetector(
          onTap: () {
            if (boardNotifier.selectedItemIds.isNotEmpty &&
                    boardNotifier.selectedItemIds.length > 1 ||
                (boardNotifier.selectedItemIds.length == 1 && !isSelected)) {
              // boardNotifier.toggleItemSelection(folder.id);
            } else {
              // this is the only selected item
              boardNotifier.toggleFolderOpenState(folder.id);
            }
          },
          child: folderContent,
        ),
      );
    } else {
      // If folder is closed, make it a DragTarget
      return DragTarget<Object>(
        // Accept BoardItem or Set<String>
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          if (data is BoardItem) {
            return data.id != folder.id &&
                data
                    is! FolderItem; // Cannot drop folder on itself or another folder
          }
          if (data is Set<String>) {
            // Dropping a selection
            final currentBoardItems =
                ref.read(boardNotifierProvider).valueOrNull ?? [];
            // Check if any item in selection is a folder or this folder itself
            for (String idInSelection in data) {
              if (idInSelection == folder.id)
                return false; // Cannot drop selection containing self onto self
              final itemInSelection = currentBoardItems.firstWhere(
                (it) => it.id == idInSelection,
                orElse: () => NoteItem(id: 'temp', x: 0, y: 0, zIndex: 0),
              ); // temp to avoid null
              if (itemInSelection is FolderItem)
                return false; // Selection cannot contain folders
            }
            return data.isNotEmpty;
          }
          return false;
        },
        onAcceptWithDetails: (details) {
          final boardNotifier = ref.read(boardNotifierProvider.notifier);
          final data = details.data;
          if (data is BoardItem) {
            boardNotifier.addItemToFolder(folder.id, data.id);
          } else if (data is Set<String>) {
            for (String itemIdInSelection in data) {
              boardNotifier.addItemToFolder(folder.id, itemIdInSelection);
            }
          }
          boardNotifier.bringToFront(
            folder.id,
          ); // Bring folder to front after adding items
        },
        builder: (context, candidateData, rejectedData) {
          bool isHoveredForDrop = candidateData.isNotEmpty;
          // This Draggable is for moving the folder itself
          return Draggable<BoardItem>(
            data: folder,
            feedback: feedbackWidget,
            childWhenDragging: childWhenDraggingWidget,
            onDragStarted: () {
              boardNotifier.bringToFront(folder.id);
              if (!isSelected) {
                boardNotifier.clearSelection();
                boardNotifier.toggleItemSelection(folder.id);
              }
            },
            child: GestureDetector(
              onTap: () {
                if (boardNotifier.selectedItemIds.isNotEmpty &&
                        boardNotifier.selectedItemIds.length > 1 ||
                    (boardNotifier.selectedItemIds.length == 1 &&
                        !isSelected)) {
                  // boardNotifier.toggleItemSelection(folder.id);
                } else {
                  // this is the only selected item
                  boardNotifier.toggleFolderOpenState(folder.id);
                }
              },
              child: Container(
                // Add highlight when hovered for drop
                decoration: BoxDecoration(
                  // Combine existing decoration with hover effect
                  color: isHoveredForDrop
                      ? Colors.brown.shade200
                      : (isOpen
                            ? Colors.brown.shade400
                            : Colors.brown.shade300),
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected || isHoveredForDrop
                      ? Border.all(
                          color: isHoveredForDrop
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : Border.all(color: Colors.transparent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isSelected ? 70 : 50),
                      blurRadius: isSelected ? 6 : 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                width: folder.width,
                height: folder.height,
                padding: const EdgeInsets.all(8.0),
                child: folderContent,
              ),
            ),
          );
        },
      );
    }
  }
}
