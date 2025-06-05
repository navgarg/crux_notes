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
    const Duration noteOpenAnimationDuration = Duration(milliseconds: 800);
    const Duration noteCloseAnimationDuration = Duration(milliseconds: 600);
    const Duration defaultAnimationDuration = Duration(milliseconds: 300);


    List<Widget> itemWidgetsToRender = [];
    Map<String, Rect> openFolderBoundingBoxes = {};
    Set<String> renderedAsFolderContentIds = {};

    final notifier = ref.read(boardNotifierProvider.notifier);

    final String? currentlyOpeningNoteId = ref.watch(
      boardNotifierProvider.select(
        (value) => value.valueOrNull != null ? notifier.openingNoteId : null,
      ),
    );

    // Fetch the actual opening note item to get its position, if any
    NoteItem? openingNoteInstance;
    if (currentlyOpeningNoteId != null) {
      final allItemsFromState =
          ref.read(boardNotifierProvider).valueOrNull ?? [];
      final foundItem = allItemsFromState.firstWhere(
        (i) => i.id == currentlyOpeningNoteId,
      );
      if (foundItem is NoteItem) {
        openingNoteInstance = foundItem;
      }
    }

    final Set<String> allContainedItemIds = {};
    for (final item in boardItems) {
      if (item is FolderItem) {
        allContainedItemIds.addAll(item.itemIds);
      }
    }

    final allSortedItems = List<BoardItem>.from(boardItems)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    Offset calculateAwayPosition(
      BoardItem currentItem,
      NoteItem? openingNote,
      BuildContext context,
    ) {
      if (openingNote == null)
        return Offset(
          currentItem.x,
          currentItem.y,
        ); // Should not happen if currentlyOpeningNoteId is set

      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      double dx = currentItem.x - (openingNote.x + openingNote.width / 2);
      double dy = currentItem.y - (openingNote.y + openingNote.height / 2);
      double distance = sqrt(dx * dx + dy * dy);
      if (distance == 0) distance = 1; // Avoid division by zero

      return Offset(
        currentItem.x +
            (dx / distance) * (screenWidth * 1.2), // Move further off-screen
        currentItem.y + (dy / distance) * (screenHeight * 1.2),
      );
    }

    // Open folders and their contents
    for (final BoardItem item in allSortedItems) {
      if (item is FolderItem && openFolderIds.contains(item.id)) {
        final folder = item;
        Offset targetPosition = Offset(folder.x, folder.y);
        Duration animationDuration = defaultAnimationDuration;

        if (currentlyOpeningNoteId != null &&
            folder.id != currentlyOpeningNoteId &&
            openingNoteInstance != null) {
          // A note is opening
          targetPosition = calculateAwayPosition(
            folder,
            openingNoteInstance,
            context,
          );
          animationDuration = noteOpenAnimationDuration;
        }
        else if (currentlyOpeningNoteId == null) {
          animationDuration = noteCloseAnimationDuration;
        }

        itemWidgetsToRender.add(
          AnimatedPositioned(
            key: ValueKey("anim_pos_${folder.id}"),
            duration: animationDuration,
            curve: Curves.easeInOut,
            left: targetPosition.dx,
            top: targetPosition.dy,
            width: folder.width,
            height: folder.height,
            child: Listener(
              onPointerDown: (_) => notifier.bringToFront(folder.id),
              child: FolderWidget(folder: folder),
            ),
          ),
        );
        // );

        final List<BoardItem> contents = boardItems
            .where((bi) => folder.itemIds.contains(bi.id))
            .toList();
        if (contents.isNotEmpty) {
          FolderContentLayout contentLayout = calculateFolderItemLayout(
            folder,
            contents,
          );

          double minX = double.infinity,
              minY = double.infinity,
              maxX = double.negativeInfinity,
              maxY = double.negativeInfinity;
          bool firstContentItem = true;

          contentLayout.itemOffsets.forEach((contentItemId, layoutOffset) {
            final contentItem = contents.firstWhere(
              (ci) => ci.id == contentItemId,
            );
            renderedAsFolderContentIds.add(contentItem.id);

            if (firstContentItem) {
              minX = layoutOffset.dx;
              minY = layoutOffset.dy;
              maxX = layoutOffset.dx + contentItem.width;
              maxY = layoutOffset.dy + contentItem.height;
              firstContentItem = false;
            } else {
              minX = min(minX, layoutOffset.dx);
              minY = min(minY, layoutOffset.dy);
              maxX = max(maxX, layoutOffset.dx + contentItem.width);
              maxY = max(maxY, layoutOffset.dy + contentItem.height);
            }

            Widget currentContentWidget;
            if (contentItem is NoteItem) {
              currentContentWidget = NoteWidget(
                key: ValueKey("content_${contentItem.id}"),
                note: contentItem,
                onPrimaryAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(noteToEdit: contentItem),
                    ),
                  );
                },
              );
            } else if (contentItem is ImageItem) {
              currentContentWidget = ImageWidget(
                key: ValueKey("content_${contentItem.id}"),
                imageItem: contentItem,
              );
            } else {
              return;
            }

            Offset contentTargetPosition =
                layoutOffset;
            Duration contentAnimationDuration = defaultAnimationDuration;

            if (currentlyOpeningNoteId != null &&
                contentItem.id != currentlyOpeningNoteId &&
                openingNoteInstance != null) {
              final tempBoardItemForCalc = NoteItem(
                id: contentItem.id,
                x: layoutOffset.dx,
                y: layoutOffset.dy,
                width: contentItem.width,
                height: contentItem.height,
                zIndex: contentItem.zIndex,
              );
              contentTargetPosition = calculateAwayPosition(
                tempBoardItemForCalc,
                openingNoteInstance,
                context,
              );
              contentAnimationDuration = noteOpenAnimationDuration;
            }
            else if (currentlyOpeningNoteId == null) {
              contentAnimationDuration = noteCloseAnimationDuration;
            }

            itemWidgetsToRender.add(
              AnimatedPositioned(
                key: ValueKey("anim_pos_content_${contentItem.id}"),
                duration: contentAnimationDuration,
                curve: Curves.easeInOut,
                left: contentTargetPosition.dx,
                top: contentTargetPosition.dy,
                width: contentItem.width,
                height: contentItem.height,
                child: Listener(
                  onPointerDown: (_) => notifier.bringToFront(contentItem.id),
                  child: currentContentWidget,
                ),
              ),
            );
          });
          const double padding = 20.0;
          if (!firstContentItem) {
            openFolderBoundingBoxes[folder.id] = Rect.fromLTRB(
              minX - padding,
              minY - padding,
              maxX + padding,
              maxY + padding,
            );
          }
        }
      }
    }

    // Top-level items
    for (final BoardItem item in allSortedItems) {
      if (item is FolderItem && openFolderIds.contains(item.id)) {
        continue;
      }
      if (allContainedItemIds.contains(item.id) &&
          !renderedAsFolderContentIds.contains(item.id)) {
        continue;
      }
      if (renderedAsFolderContentIds.contains(item.id)) {
        continue;
      }

      Widget currentItemWidget;
      if (item is NoteItem) {
        currentItemWidget = NoteWidget(
          key: ValueKey(item.id),
          note: item,
          onPrimaryAction: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoteEditorScreen(noteToEdit: item),
              ),
            );
          },
        );
      } else if (item is ImageItem) {
        currentItemWidget = ImageWidget(
          key: ValueKey(item.id),
          imageItem: item,
        );
      } else if (item is FolderItem) {
        // Closed folder
        currentItemWidget = FolderWidget(key: ValueKey(item.id), folder: item);
      } else {
        continue;
      }

      Offset targetPosition = Offset(item.x, item.y);
      Duration animationDuration = defaultAnimationDuration;

      if (currentlyOpeningNoteId != null && item.id != currentlyOpeningNoteId && openingNoteInstance != null) {
        targetPosition = calculateAwayPosition(item, openingNoteInstance, context);
        animationDuration = noteOpenAnimationDuration;
      }else if (currentlyOpeningNoteId == null) {
        animationDuration = noteCloseAnimationDuration;
      }

      itemWidgetsToRender.add(
        AnimatedPositioned( // Top-level items are animated
          key: ValueKey("anim_pos_${item.id}"),
          duration: animationDuration,
          curve: Curves.easeInOut,
          left: targetPosition.dx,
          top: targetPosition.dy,
          width: item.width,
          height: item.height,
          child: Listener(
            onPointerDown: (_) => notifier.bringToFront(item.id),
            child: currentItemWidget,
          ),
        ),
      );
    }

    List<Widget> finalRenderList = [];
    openFolderBoundingBoxes.forEach((folderId, rect) {
      bool folderIsVisible = true;
      if (currentlyOpeningNoteId != null && openingNoteInstance != null) {
        final folderItem = allSortedItems.firstWhere((it) => it.id == folderId);
        Offset folderTargetPos = calculateAwayPosition(folderItem, openingNoteInstance, context);
        // Heuristic: if target is far, it's "away"
        if ((folderTargetPos.dx - folderItem.x).abs() > 100 || (folderTargetPos.dy - folderItem.y).abs() > 100) {
          folderIsVisible = false;
        }
            }
      if (folderIsVisible) {
        finalRenderList.add(FolderBoundingBoxWidget(key: ValueKey("bbox_$folderId"), rect: rect));
      }
    });
    finalRenderList.addAll(itemWidgetsToRender);

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final boardNotifier = ref.read(boardNotifierProvider.notifier);
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset localDropOffset = renderBox.globalToLocal(details.offset);

        final List<BoardItem> currentBoardStateItems =
            ref.read(boardNotifierProvider).valueOrNull ?? [];
        final Set<String> currentlyOpenFolderIds = ref
            .read(boardNotifierProvider.notifier)
            .openFolderIds;

        if (details.data is BoardItem) {
          final droppedItem = details.data as BoardItem;
          if (droppedItem is FolderItem) {
            // Prevent dragging folders into open folders or onto board in a way that changes their structure
            print("Folder dropped, updating its position.");
            boardNotifier.updateItemGeometricProperties(
              droppedItem.id,
              newX: localDropOffset.dx,
              newY: localDropOffset.dy,
            );
            boardNotifier.bringToFront(droppedItem.id);
            return;
          }

          String?
          sourceFolderId; // Folder the item was dragged FROM (if it was in an open one)
          for (final openFolderId in currentlyOpenFolderIds) {
            final folder =
                currentBoardStateItems.firstWhere(
                      (item) => item.id == openFolderId,
                    )
                    as FolderItem;
            if (folder.itemIds.contains(droppedItem.id)) {
              sourceFolderId = openFolderId;
              break;
            }
          }

          String? targetOpenFolderId; // Open folder the item is dropped INTO
          for (final entry in openFolderBoundingBoxes.entries) {
            // Ensure the folder itself is not the dropped item, prevent dropping item into its own visual representation's bbox
            if (entry.key != droppedItem.id &&
                entry.value.contains(localDropOffset)) {
              targetOpenFolderId = entry.key;
              break;
            }
          }

          print(
            "Dropped: ${droppedItem.id}, Source: $sourceFolderId, Target Open: $targetOpenFolderId, Offset: $localDropOffset",
          );

          if (sourceFolderId != null) {
            // Item was dragged from an open folder
            if (targetOpenFolderId != null) {
              // And dropped into an open folder's bounding box
              if (sourceFolderId == targetOpenFolderId) {
                print(
                  "Item ${droppedItem.id} moved within same folder ${sourceFolderId}. No change in membership.",
                );
              } else {
                // Moved from sourceFolderId to targetOpenFolderId
                print(
                  "Item ${droppedItem.id} moved from open folder $sourceFolderId to open folder $targetOpenFolderId",
                );
                boardNotifier.addItemToFolder(
                  targetOpenFolderId,
                  droppedItem.id,
                );
              }
            } else {
              // Dragged out of sourceFolderId onto the main board
              print(
                "Item ${droppedItem.id} dragged out of open folder $sourceFolderId to board.",
              );
              boardNotifier.removeItemFromFolder(
                sourceFolderId,
                droppedItem.id,
                newX: localDropOffset.dx,
                newY: localDropOffset.dy,
              );
            }
          } else {
            if (targetOpenFolderId != null) {
              // Dragged from board into an open folder's bounding box
              print(
                "Item ${droppedItem.id} dragged from board into open folder $targetOpenFolderId.",
              );
              boardNotifier.addItemToFolder(targetOpenFolderId, droppedItem.id);
            } else {
              // Item dragged on the board itself (not from/to an open folder)
              print("Item ${droppedItem.id} dragged on the board.");
              boardNotifier.updateItemGeometricProperties(
                droppedItem.id,
                newX: localDropOffset.dx,
                newY: localDropOffset.dy,
              );
            }
          }
          boardNotifier.bringToFront(targetOpenFolderId ?? droppedItem.id);
        } else if (details.data is Set<String>) {
          final Set<String> selectedIds = details.data as Set<String>;
          print(
            "Group of items $selectedIds dropped on board. Individual Draggables should manage group move.",
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(children: finalRenderList);
      },
    );
  }
}
