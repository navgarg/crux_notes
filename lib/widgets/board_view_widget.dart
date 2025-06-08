import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_item.dart';
import '../models/folder_item.dart';
import '../models/image_item.dart';
import '../models/note_item.dart';
import '../providers/board_providers.dart';
import '../screens/note_editor_screen.dart';
import '../utils/board_layout_utils.dart';
import '../widgets/folders/folder_widget.dart';
import '../widgets/images/image_widget.dart';
import '../widgets/note_widget.dart';
import 'folders/folder_bounding_box.dart';

/// Renders all board items with complex animations for interactions like
/// opening/closing folders, dragging items, and editing notes.
class BoardViewWidget extends ConsumerWidget {
  final List<BoardItem> boardItems;
  final Set<String> openFolderIds;

  const BoardViewWidget({
    super.key,
    required this.boardItems,
    required this.openFolderIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //region Animation Constants
    // Defines timing and curves for various UI animations.
    const Duration noteOpenAnimationDuration = Duration(milliseconds: 800);
    const Duration noteCloseAnimationDuration = Duration(milliseconds: 600);
    const Duration folderOpenCloseDuration = Duration(milliseconds: 450);
    const Duration itemEvasionDuration = Duration(milliseconds: 350);
    const Duration itemDragSnapDuration = Duration.zero; // For immediate feedback
    const Curve folderOpenCurve = Curves.easeOutCubic;
    const Curve folderCloseCurve = Curves.easeInCubic;
    const Curve itemEvasionCurve = Curves.easeOutCubic;
    //endregion

    //region State and Notifier Access
    // Centralized access to providers and screen-related data.
    final notifier = ref.read(boardNotifierProvider.notifier);
    final screenSize = MediaQuery.of(context).size;
    final justManipulatedId = notifier.justManipulatedItemId;
    final openingNoteId = notifier.openingNoteId;
    final activelyResizingId = notifier.activelyResizingItemId;

    NoteItem? openingNoteInstance;
    if (openingNoteId != null) {
      final foundItem = boardItems.firstWhere((i) => i.id == openingNoteId);
      if (foundItem is NoteItem) {
        openingNoteInstance = foundItem;
      }
    }
    //endregion

    //region Layout Pre-computation
    // Pre-calculating layouts and relationships outside the build loop improves performance.
    final allFoldersMap = {for (var item in boardItems.whereType<FolderItem>()) item.id: item};
    final Map<String, String> itemToParentFolderMap = {};
    for (final folder in allFoldersMap.values) {
      for (final itemId in folder.itemIds) {
        itemToParentFolderMap[itemId] = folder.id;
      }
    }

    // Calculate the "spread-out" layout positions for items inside currently open folders.
    final Map<String, FolderContentLayout> openFolderLayouts = {};
    for (final folder in allFoldersMap.values.where((f) => openFolderIds.contains(f.id))) {
      final contents = boardItems.where((bi) => folder.itemIds.contains(bi.id)).toList();
      openFolderLayouts[folder.id] = calculateFolderItemLayout(folder, contents, screenSize.width);
    }

    // Determine the visible bounding box for each open folder's content area.
    final Map<String, Rect> openFolderBoundingBoxes = {};
    openFolderLayouts.forEach((folderId, layout) {
      final folder = allFoldersMap[folderId]!;
      double minX = folder.x, minY = folder.y;
      double maxX = folder.x + folder.width, maxY = folder.y + folder.height;

      layout.itemOffsets.forEach((contentItemId, offset) {
        final contentItem = boardItems.firstWhere((i) => i.id == contentItemId);
        minX = min(minX, offset.dx);
        minY = min(minY, offset.dy);
        maxX = max(maxX, offset.dx + contentItem.width);
        maxY = max(maxY, offset.dy + contentItem.height);
      });

      const padding = 20.0;
      openFolderBoundingBoxes[folderId] = Rect.fromLTRB(
        minX - padding,
        minY - padding,
        maxX + padding,
        maxY + padding,
      );
    });
    //endregion

    //region Main Render Loop
    // A single, unified loop renders all items, simplifying state management and enabling animations.
    final allSortedItems = List<BoardItem>.from(boardItems)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    List<Widget> renderedWidgets = [];

    Offset calculateAwayPosition(BoardItem currentItem, NoteItem openingNote) {
      double dx = currentItem.x - (openingNote.x + openingNote.width / 2);
      double dy = currentItem.y - (openingNote.y + openingNote.height / 2);
      double distance = sqrt(dx * dx + dy * dy);
      if (distance == 0) distance = 1;

      return Offset(
        currentItem.x + (dx / distance) * (screenSize.width * 1.2),
        currentItem.y + (dy / distance) * (screenSize.height * 1.2),
      );
    }

    for (final item in allSortedItems) {
      Offset targetPosition;
      double targetOpacity = 1.0;
      Duration animationDuration = noteCloseAnimationDuration;
      Curve animationCurve = Curves.easeInOut;
      bool isInteractive = true;

      final parentFolderId = itemToParentFolderMap[item.id];

      if (parentFolderId != null) {
        // --- Logic for items within a folder ---
        final parentFolder = allFoldersMap[parentFolderId]!;
        final isParentOpen = openFolderIds.contains(parentFolderId);

        if (isParentOpen) {
          // If parent is open, item animates to its calculated layout position.
          targetPosition = openFolderLayouts[parentFolderId]!.itemOffsets[item.id]!;
          animationDuration = folderOpenCloseDuration;
          animationCurve = folderOpenCurve;
        } else {
          // If parent is closed, item is positioned at the folder's center and made
          // invisible. This provides a "from" state for the opening animation.
          targetPosition = Offset(
            parentFolder.x + (parentFolder.width / 2) - (item.width / 2),
            parentFolder.y + (parentFolder.height / 2) - (item.height / 2),
          );
          targetOpacity = 0.0;
          animationDuration = folderOpenCloseDuration;
          animationCurve = folderCloseCurve;
          isInteractive = false;
        }
      } else {
        // --- Logic for top-level items (including folder icons) ---
        targetPosition = Offset(item.x, item.y);
        bool isEvading = false;

        // Evasion logic: top-level items move to avoid open folder content areas.
        if (openingNoteId == null) {
          const double itemMarginHorizontal = 24.0;
          for (final folderEntry in openFolderBoundingBoxes.entries) {
            // A folder icon should not evade its own content area.
            if (item.id == folderEntry.key) {
              continue;
            }

            final Rect folderBounds = folderEntry.value;
            final Rect itemRect = Rect.fromLTWH(targetPosition.dx, targetPosition.dy, item.width, item.height);

            if (itemRect.overlaps(folderBounds)) {
              isEvading = true;
              double evasionX = targetPosition.dx;

              // Push the item to the nearest horizontal side.
              bool isItemOnLeft = itemRect.center.dx < folderBounds.center.dx;
              if (isItemOnLeft) {
                evasionX = folderBounds.left - item.width - itemMarginHorizontal;
              } else {
                evasionX = folderBounds.right + itemMarginHorizontal;
              }
              targetPosition = Offset(evasionX, targetPosition.dy);
            }
          }
        }

        // Set animation type with priority: drag > evasion > note interaction.
        if (justManipulatedId == item.id || (item is ImageItem && activelyResizingId == item.id)) {
          animationDuration = itemDragSnapDuration;
        } else if (isEvading) {
          animationDuration = itemEvasionDuration;
          animationCurve = itemEvasionCurve;
        } else if (openingNoteId != null && item.id != openingNoteId && openingNoteInstance != null) {
          targetPosition = calculateAwayPosition(item, openingNoteInstance);
          animationDuration = noteOpenAnimationDuration;
        }
      }

      Widget currentItemWidget;
      if (item is NoteItem) {
        currentItemWidget = NoteWidget(
          note: item,
          onPrimaryAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteToEdit: item))),
        );
      } else if (item is ImageItem) {
        currentItemWidget = ImageWidget(imageItem: item);
      } else if (item is FolderItem) {
        currentItemWidget = FolderWidget(folder: item);
      } else {
        continue;
      }

      renderedWidgets.add(
        AnimatedPositioned(
          key: ValueKey("positioned_item_${item.id}"),
          duration: animationDuration,
          curve: animationCurve,
          left: targetPosition.dx,
          top: targetPosition.dy,
          width: item.width,
          height: item.height,
          child: AnimatedOpacity(
            duration: folderOpenCloseDuration,
            opacity: targetOpacity,
            child: IgnorePointer(
              ignoring: !isInteractive,
              child: currentItemWidget,
            ),
          ),
        ),
      );
    }
    //endregion

    //region Bounding Box Rendering
    // Renders the visual bounding boxes for open folders separately.
    final List<Widget> boundingBoxWidgets = [];
    openFolderBoundingBoxes.forEach((folderId, rect) {
      boundingBoxWidgets.add(
        Positioned(
          key: ValueKey("bbox_$folderId"),
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: openFolderIds.contains(folderId) ? 1.0 : 0.0,
            child: FolderBoundingBoxWidget(rect: rect),
          ),
        ),
      );
    });
    //endregion

    // The main DragTarget for the board, handling drops onto the background.
    return DragTarget<BoardItem>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final boardNotifier = ref.read(boardNotifierProvider.notifier);
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset localDropOffset = renderBox.globalToLocal(details.offset);
        final BoardItem droppedBoardItem = details.data;
        final String? activePrimaryDraggedIdFromNotifier = boardNotifier.primaryDraggedItemIdForGroup;
        final Set<String> selectedIdsFromNotifierAtDrop = Set.from(boardNotifier.selectedItemIds);
        final Offset? activePrimaryDragStartOffsetFromNotifier = boardNotifier.primaryDragStartOffsetOnBoard;
        final Map<String, Offset> activeInitialGroupOffsetsFromNotifier = Map.from(boardNotifier.initialGroupDragItemOffsets);

        if (activePrimaryDraggedIdFromNotifier != null &&
            droppedBoardItem.id == activePrimaryDraggedIdFromNotifier &&
            selectedIdsFromNotifierAtDrop.contains(activePrimaryDraggedIdFromNotifier) &&
            selectedIdsFromNotifierAtDrop.length > 1) {
          // Handles dropping a group of items.
          final Set<String> groupIdsToMove = selectedIdsFromNotifierAtDrop;
          final Offset primaryItemNewProposedTopLeft = localDropOffset;
          Map<String, Offset> proposedNewPositionsForGroup = {};
          for (String itemId in groupIdsToMove) {
            final itemModel = (ref.read(boardNotifierProvider).valueOrNull ?? []).firstWhere((i) => i.id == itemId);
            if (itemId == activePrimaryDraggedIdFromNotifier) {
              proposedNewPositionsForGroup[itemId] = primaryItemNewProposedTopLeft;
            } else {
              final relativeOffset = activeInitialGroupOffsetsFromNotifier[itemId];
              if (relativeOffset != null) {
                proposedNewPositionsForGroup[itemId] = Offset(primaryItemNewProposedTopLeft.dx + relativeOffset.dx, primaryItemNewProposedTopLeft.dy + relativeOffset.dy);
              } else {
                final double deltaX = primaryItemNewProposedTopLeft.dx - activePrimaryDragStartOffsetFromNotifier!.dx;
                final double deltaY = primaryItemNewProposedTopLeft.dy - activePrimaryDragStartOffsetFromNotifier.dy;
                proposedNewPositionsForGroup[itemId] = Offset(itemModel.x + deltaX, itemModel.y + deltaY);
              }
            }
          }
          double groupMinX = double.infinity, groupMinY = double.infinity;
          double groupMaxX = double.negativeInfinity, groupMaxY = double.negativeInfinity;
          proposedNewPositionsForGroup.forEach((itemId, pos) {
            final itemModel = (ref.read(boardNotifierProvider).valueOrNull ?? []).firstWhere((i) => i.id == itemId);
            groupMinX = min(groupMinX, pos.dx);
            groupMinY = min(groupMinY, pos.dy);
            groupMaxX = max(groupMaxX, pos.dx + itemModel.width);
            groupMaxY = max(groupMaxY, pos.dy + itemModel.height);
          });
          Map<String, Offset> finalNewPositionsForGroup = {};
          double adjustX = 0, adjustY = 0;
          if (groupMinX < 0) adjustX = -groupMinX;
          else if (groupMaxX > screenSize.width) adjustX = screenSize.width - groupMaxX;
          if (groupMinY < 0) adjustY = -groupMinY;
          else if (groupMaxY > screenSize.height) adjustY = screenSize.height - groupMaxY;
          proposedNewPositionsForGroup.forEach((itemId, pos) {
            finalNewPositionsForGroup[itemId] = Offset(pos.dx + adjustX, pos.dy + adjustY);
            boardNotifier.itemWasJustManipulated(itemId);
          });
          if (finalNewPositionsForGroup.isNotEmpty) {
            boardNotifier.updateItemGroupPositions(finalNewPositionsForGroup);
          } else {
            boardNotifier.endGroupDrag();
          }
        } else {
          // Handles dropping a single item.
          final droppedItem = details.data;
          Offset newProposedTopLeft = localDropOffset;
          if (newProposedTopLeft.dx < 0) newProposedTopLeft = Offset(0, newProposedTopLeft.dy);
          if (newProposedTopLeft.dx + droppedItem.width > screenSize.width) newProposedTopLeft = Offset(screenSize.width - droppedItem.width, newProposedTopLeft.dy);
          if (newProposedTopLeft.dy < 0) newProposedTopLeft = Offset(newProposedTopLeft.dx, 0);
          if (newProposedTopLeft.dy + droppedItem.height > screenSize.height) newProposedTopLeft = Offset(newProposedTopLeft.dx, screenSize.height - droppedItem.height);

          bool wasMovedOnBoardWithoutFolderMembershipChange = false;
          if (droppedItem is! FolderItem) {
            final List<BoardItem> currentBoardStateItems = ref.read(boardNotifierProvider).valueOrNull ?? [];
            final Set<String> currentOpenFolderIdsForInteraction = notifier.openFolderIds;
            String? sourceFolderId;
            for (final openFolderId in currentOpenFolderIdsForInteraction) {
              final folder = currentBoardStateItems.firstWhere((item) => item.id == openFolderId && item is FolderItem) as FolderItem?;
              if (folder != null && folder.itemIds.contains(droppedItem.id)) {
                sourceFolderId = openFolderId;
                break;
              }
            }
            String? targetOpenFolderId;
            final currentOpenBoxes = openFolderBoundingBoxes;
            for (final entry in currentOpenBoxes.entries) {
              if (entry.key != droppedItem.id && entry.value.contains(localDropOffset)) {
                targetOpenFolderId = entry.key;
                break;
              }
            }
            if (sourceFolderId != null) {
              if (targetOpenFolderId != null) {
                if (sourceFolderId != targetOpenFolderId) {
                  boardNotifier.addItemToFolder(targetOpenFolderId, droppedItem.id);
                } else {
                  boardNotifier.updateItemGeometricProperties(droppedItem.id, newX: newProposedTopLeft.dx, newY: newProposedTopLeft.dy);
                  wasMovedOnBoardWithoutFolderMembershipChange = true;
                }
              } else {
                boardNotifier.removeItemFromFolder(sourceFolderId, droppedItem.id, newX: newProposedTopLeft.dx, newY: newProposedTopLeft.dy);
                wasMovedOnBoardWithoutFolderMembershipChange = true;
              }
            } else {
              if (targetOpenFolderId != null) {
                boardNotifier.addItemToFolder(targetOpenFolderId, droppedItem.id);
              } else {
                boardNotifier.updateItemGeometricProperties(droppedItem.id, newX: newProposedTopLeft.dx, newY: newProposedTopLeft.dy);
                wasMovedOnBoardWithoutFolderMembershipChange = true;
              }
            }
            boardNotifier.bringToFront(targetOpenFolderId ?? droppedItem.id);
          } else {
            boardNotifier.updateItemGeometricProperties(droppedItem.id, newX: newProposedTopLeft.dx, newY: newProposedTopLeft.dy);
            wasMovedOnBoardWithoutFolderMembershipChange = true;
            boardNotifier.bringToFront(droppedItem.id);
          }
          if (wasMovedOnBoardWithoutFolderMembershipChange) {
            boardNotifier.itemWasJustManipulated(droppedItem.id);
          }
          boardNotifier.endGroupDrag();
        }
        boardNotifier.endGroupDrag();
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            ...boundingBoxWidgets,
            ...renderedWidgets,
          ],
        );
      },
    );
  }
}