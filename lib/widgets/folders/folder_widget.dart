import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/board_item.dart';
import '../../models/folder_item.dart';
import '../../models/note_item.dart';
import '../../providers/board_providers.dart';

class FolderWidget extends ConsumerStatefulWidget {
  // Changed to StatefulWidget
  final FolderItem folder;
  final VoidCallback? onPrimaryAction; // Keep this if used elsewhere

  const FolderWidget({super.key, required this.folder, this.onPrimaryAction});

  @override
  ConsumerState<FolderWidget> createState() => _FolderWidgetState();
}

class _FolderWidgetState extends ConsumerState<FolderWidget> {
  bool _isEditingName = false;
  bool _isHovering = false;
  late TextEditingController _nameEditingController;
  FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameEditingController = TextEditingController(text: widget.folder.name);
    _nameFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant FolderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.folder.name != oldWidget.folder.name && !_isEditingName) {
      _nameEditingController.text = widget.folder.name;
    }
  }

  void _handleFocusChange() {
    if (!_nameFocusNode.hasFocus && _isEditingName) {
      // Focus lost while editing, submit the changes
      _submitNewName();
    }
  }

  void _submitNewName() {
    if (_nameEditingController.text.isNotEmpty &&
        _nameEditingController.text != widget.folder.name) {
      ref
          .read(boardNotifierProvider.notifier)
          .updateItem(
            FolderItem(
              id: widget.folder.id,
              x: widget.folder.x,
              y: widget.folder.y,
              width: widget.folder.width,
              height: widget.folder.height,
              zIndex: widget.folder.zIndex,
              name: _nameEditingController.text,
              itemIds: widget.folder.itemIds,
              createdAt: widget.folder.createdAt,
            ),
          );
    }
    if (mounted) {
      setState(() {
        _isEditingName = false;
      });
    }
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_handleFocusChange);
    _nameEditingController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        .contains(widget.folder.id);
    final boardState = ref.watch(boardNotifierProvider);
    final Set<String> selectedIds = boardState.hasValue
        ? ref.read(boardNotifierProvider.notifier).selectedItemIds
        : const {};

    final bool isOpen = openFolderIds.contains(widget.folder.id);

    Widget nameWidget;
    if (_isEditingName) {
      nameWidget = SizedBox(
        height: 25,
        child: TextField(
          controller: _nameEditingController,
          focusNode: _nameFocusNode,
          autofocus: true,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.brown.shade900,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitNewName(),
        ),
      );
    } else {
      nameWidget = Text(
        widget.folder.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.brown.shade900,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final folderContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isOpen ? Icons.folder_open : Icons.folder,
          size: 40,
          color: Colors.brown.shade700,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onDoubleTap: () {
            if (isOpen) {
              print("Renaming open folders is currently disabled.");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Close the folder to rename it."),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            if (mounted) {
              setState(() {
                _isEditingName = true;
                _nameEditingController.text =
                    widget.folder.name;
                // Request focus after a short delay to ensure TextField is built
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _nameFocusNode.requestFocus();
                  _nameEditingController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _nameEditingController.text.length,
                  );
                });
              });
            }
          },
          child: nameWidget,
        ),
      ],
    );

    final feedbackWidget = Material(
      elevation: 4.0,
      color: Colors.transparent,
      child: Container(
        width: widget.folder.width,
        height: widget.folder.height,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.brown.shade300.withAlpha((255 * 0.8).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: folderContent,
      ),
    );

    final childWhenDraggingWidget = Container(
      width: widget.folder.width,
      height: widget.folder.height,
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
        data: widget.folder,
        feedback: feedbackWidget,
        childWhenDragging: childWhenDraggingWidget,
        onDragStarted: () {
          final boardNotifier = ref.read(boardNotifierProvider.notifier);
          boardNotifier.bringToFront(widget.folder.id); // Bring the physically grabbed item to front

          Set<String> selectedIdsAtDragStart = Set.from(boardNotifier.selectedItemIds);
          bool wasThisItemAlreadySelected = selectedIdsAtDragStart.contains(widget.folder.id);

          if (wasThisItemAlreadySelected && selectedIdsAtDragStart.length > 1) {
            // Case 1: The grabbed item was already part of a multi-item selection.
            // This is a group drag.
            print("Draggable: Drag started on ${widget.folder.id} as part of existing group ${selectedIdsAtDragStart}");
            selectedIdsAtDragStart.forEach((id) {
              if (id != widget.folder.id) boardNotifier.bringToFront(id); // Bring other group members to front too
            });
            boardNotifier.startGroupDrag(selectedIdsAtDragStart, widget.folder.id);
          } else {
            // Case 2: The grabbed item was NOT part of a multi-item selection.
            // It proceeds as a single item drag.
            if (!wasThisItemAlreadySelected || selectedIdsAtDragStart.length > 1) {
              // If it wasn't selected OR if other items were selected
              print("Draggable: Drag started on ${widget.folder.id}. It now becomes the sole selected item for this drag operation.");
              boardNotifier.clearSelection();
              boardNotifier.toggleItemSelection(widget.folder.id); // Selects only this item
            } else {
              // It was already the only selected item. No change to selection needed.
              print("Draggable: Drag started on ${widget.folder.id} which was already solely selected.");
            }
            // For a single item drag, ensure any previous group drag state is cleared.
            boardNotifier.endGroupDrag();
            print("Draggable: ${widget.folder.id} is being dragged alone (not as a group leader).");
          }
        },

        onDragEnd: (details) {
          if (details.wasAccepted) return; // Position updated by DragTarget

          final notifier = ref.read(boardNotifierProvider.notifier);
          print("Draggable for ${widget.folder.id}: Drag was NOT accepted. Clearing group state.");
          notifier.endGroupDrag();
        },
        child: GestureDetector(
          onTap: () {
            const snackBar = SnackBar(content: Text('Cannot select a folder when open'));
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          },
          onDoubleTap: () {
            if (_isEditingName) return;
            if (boardNotifier.selectedItemIds.isNotEmpty &&
                    boardNotifier.selectedItemIds.length > 1 ||
                (boardNotifier.selectedItemIds.length == 1 && !isSelected)) {
              // boardNotifier.toggleItemSelection(folder.id);
            } else {
              // this is the only selected item
              boardNotifier.toggleFolderOpenState(widget.folder.id);
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
            return data.id != widget.folder.id &&
                data
                    is! FolderItem; // Cannot drop folder on itself or another folder
          }
          if (data is Set<String>) {
            // Dropping a selection
            final currentBoardItems =
                ref.read(boardNotifierProvider).valueOrNull ?? [];
            // Check if any item in selection is a folder or this folder itself
            for (String idInSelection in data) {
              if (idInSelection == widget.folder.id)
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
            boardNotifier.addItemToFolder(widget.folder.id, data.id);
          } else if (data is Set<String>) {
            for (String itemIdInSelection in data) {
              boardNotifier.addItemToFolder(
                widget.folder.id,
                itemIdInSelection,
              );
            }
          }
          boardNotifier.bringToFront(
            widget.folder.id,
          ); // Bring folder to front after adding items
        },
        builder: (context, candidateData, rejectedData) {
          bool isHoveredForDrop = candidateData.isNotEmpty;
          // This Draggable is for moving the folder itself
          return Draggable<BoardItem>(
            data: widget.folder,
            feedback: feedbackWidget,
            childWhenDragging: childWhenDraggingWidget,
            onDragStarted: () {
              final boardNotifier = ref.read(boardNotifierProvider.notifier);
              boardNotifier.bringToFront(widget.folder.id); // Bring the physically grabbed item to front

              Set<String> selectedIdsAtDragStart = Set.from(boardNotifier.selectedItemIds);
              bool wasThisItemAlreadySelected = selectedIdsAtDragStart.contains(widget.folder.id);

              if (wasThisItemAlreadySelected && selectedIdsAtDragStart.length > 1) {
                // Case 1: The grabbed item was already part of a multi-item selection.
                // This is a group drag.
                print("Draggable: Drag started on ${widget.folder.id} as part of existing group ${selectedIdsAtDragStart}");
                selectedIdsAtDragStart.forEach((id) {
                  if (id != widget.folder.id) boardNotifier.bringToFront(id); // Bring other group members to front too
                });
                boardNotifier.startGroupDrag(selectedIdsAtDragStart, widget.folder.id);
              } else {
                // Case 2: The grabbed item was NOT part of a multi-item selection.
                // It proceeds as a single item drag.
                if (!wasThisItemAlreadySelected || selectedIdsAtDragStart.length > 1) {
                  // If it wasn't selected OR if other items were selected
                  print("Draggable: Drag started on ${widget.folder.id}. It now becomes the sole selected item for this drag operation.");
                  boardNotifier.clearSelection();
                  boardNotifier.toggleItemSelection(widget.folder.id); // Selects only this item
                } else {
                  // It was already the only selected item. No change to selection needed.
                  print("Draggable: Drag started on ${widget.folder.id} which was already solely selected.");
                }
                // For a single item drag, ensure any previous group drag state is cleared.
                boardNotifier.endGroupDrag();
                print("Draggable: ${widget.folder.id} is being dragged alone (not as a group leader).");
              }
            },
            onDragEnd: (details) {
              if (details.wasAccepted) return; // Position updated by DragTarget

              final notifier = ref.read(boardNotifierProvider.notifier);
              print("Draggable for ${widget.folder.id}: Drag was NOT accepted. Clearing group state.");
              notifier.endGroupDrag();
            },
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                onTap: () {
                  final notifier = ref.read(boardNotifierProvider.notifier);
                  notifier.toggleItemSelection(widget.folder.id);
                  print("folder tapped. selection toggled");
                },
                onDoubleTap: () {
                  if (_isEditingName) return;
                  if (boardNotifier.selectedItemIds.isNotEmpty &&
                      boardNotifier.selectedItemIds.length > 1 ||
                      (boardNotifier.selectedItemIds.length == 1 && !isSelected)) {
                    // boardNotifier.toggleItemSelection(folder.id);
                  } else {
                    // this is the only selected item
                    boardNotifier.toggleFolderOpenState(widget.folder.id);
                  }
                  if (boardNotifier.selectedItemIds.isNotEmpty){
                    const snackBar = SnackBar(content: Text('Cannot select a folder item'));
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
                  width: widget.folder.width,
                  height: widget.folder.height,
                  padding: const EdgeInsets.all(8.0),
                  child: folderContent,
                ),
              ),
            ),
          );
        },
      );
    }
  }
}
