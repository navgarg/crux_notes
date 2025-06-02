import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/board_item.dart';
import '../../models/folder_item.dart';
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
        Icon(isOpen ? Icons.folder_open : Icons.folder, size: 40, color: Colors.brown.shade700),
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
          if (boardNotifier.selectedItemIds.isNotEmpty && boardNotifier.selectedItemIds.length >1 || (boardNotifier.selectedItemIds.length == 1 && !isSelected)) {
            boardNotifier.toggleItemSelection(folder.id);
          } else { // this is the only selected item
            boardNotifier.toggleFolderOpenState(folder.id);
          }
        },
        onLongPress: () {
          final notifier = ref.read(boardNotifierProvider.notifier);
          // notifier.bringToFront(folder.id);
          notifier.toggleItemSelection(folder.id);
        },
        child: Container(
          width: folder.width,
          height: folder.height,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: isOpen ? Colors.brown.shade400 : Colors.brown.shade300,
            borderRadius: BorderRadius.circular(8),
            border:
                isSelected // Conditional border
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
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
          child: folderContent,
        ),
      ),
    );
  }
}
