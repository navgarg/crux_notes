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
    const Duration itemDragSnapDuration = Duration(milliseconds: 0);

    List<Widget> itemWidgetsToRender = [];
    Map<String, Rect> openFolderBoundingBoxes = {};
    Set<String> renderedAsFolderContentIds = {};

    final notifier = ref.read(boardNotifierProvider.notifier);

    final String? justManipulatedIdFromNotifier = ref.watch(
      boardNotifierProvider.select((s) => notifier.justManipulatedItemId),
    );

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
      if (openingNote == null) {
        return Offset(
          currentItem.x,
          currentItem.y,
        );
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      double dx = currentItem.x - (openingNote.x + openingNote.width / 2);
      double dy = currentItem.y - (openingNote.y + openingNote.height / 2);
      double distance = sqrt(dx * dx + dy * dy);
      if (distance == 0) distance = 1;

      return Offset(
        currentItem.x +
            (dx / distance) * (screenWidth * 1.2),
        currentItem.y + (dy / distance) * (screenHeight * 1.2),
      );
    }

    for (final BoardItem item in allSortedItems) {
      // Iterate through ALL items to find folders first
      if (item is FolderItem) {
        final folder = item;
        final bool isThisFolderActuallyOpen = openFolderIds.contains(folder.id);

        // This part animates the folder icon if a note opens, or if it's dragged.
        Offset folderIconTargetPosition = Offset(folder.x, folder.y);
        Duration folderIconAnimationDuration;
        if (justManipulatedIdFromNotifier == folder.id) {
          folderIconAnimationDuration = itemDragSnapDuration;
        } else if (currentlyOpeningNoteId != null &&
            folder.id != currentlyOpeningNoteId &&
            openingNoteInstance != null) {
          folderIconTargetPosition = calculateAwayPosition(
            folder,
            openingNoteInstance,
            context,
          );
          folderIconAnimationDuration = noteOpenAnimationDuration;
        } else if (currentlyOpeningNoteId == null) {
          folderIconAnimationDuration = noteCloseAnimationDuration;
        } else {
          folderIconAnimationDuration = defaultAnimationDuration;
        }
        itemWidgetsToRender.add(
          AnimatedPositioned(
            key: ValueKey(
              "anim_pos_folder_icon_${folder.id}",
            ),
            duration: folderIconAnimationDuration,
            curve: Curves.easeInOut,
            left: folderIconTargetPosition.dx,
            top: folderIconTargetPosition.dy,
            width: folder.width,
            height: folder.height,
            child: Listener(
              onPointerDown: (_) => notifier.bringToFront(folder.id),
              child: FolderWidget(folder: folder),
            ),
          ),
        );

        //Logic for Folder CONTENTS (process for ALL folders, animate based on isThisFolderActuallyOpen)
        final List<BoardItem> contents = boardItems
            .where((bi) => folder.itemIds.contains(bi.id))
            .toList();

        // Initialize bounding box calculation variables
        double currentFolderMinX = folderIconTargetPosition.dx;
        double currentFolderMinY = folderIconTargetPosition.dy;
        double currentFolderMaxX = folderIconTargetPosition.dx + folder.width;
        double currentFolderMaxY = folderIconTargetPosition.dy + folder.height;

        if (contents.isNotEmpty) {
          FolderContentLayout contentLayout = calculateFolderItemLayout(
            folder,
            contents,
            MediaQuery.of(context).size.width
          );

          contentLayout.itemOffsets.forEach((contentItemId, layoutOffset) {
            final contentItem = contents.firstWhere(
              (ci) => ci.id == contentItemId,
            );
            // Add to renderedAsFolderContentIds so they are not rendered again by the top-level loop
            renderedAsFolderContentIds.add(contentItem.id);

            print(
              "Content ID: ${contentItem.id}, layoutOffset: $layoutOffset, contentItem.width: ${contentItem.width}, contentItem.height: ${contentItem.height}",
            );

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

            Offset itemInitialPositionWithinFolder = Offset(
              folderIconTargetPosition.dx +
                  folder.width / 2 -
                  contentItem.width / 2,
              folderIconTargetPosition.dy +
                  folder.height / 2 -
                  contentItem.height / 2,
            );

            Offset finalContentTargetPosition;
            Duration finalContentAnimationDuration;
            Curve finalItemAnimationCurve = Curves.easeInOut;
            double finalItemOpacity;

            print(
              "Processing Content: Folder ${folder.id}, Item ${contentItem.id}, isThisFolderActuallyOpen: $isThisFolderActuallyOpen, externalNoteOpening: $currentlyOpeningNoteId",
            );

            if (currentlyOpeningNoteId != null &&
                contentItem.id != currentlyOpeningNoteId &&
                openingNoteInstance != null) {
              // External note opening: content item moves away from its layoutOffset
              // BUT, if the folder itself is also moving away, this needs to be relative or an absolute "away" spot
              final tempBoardItemForCalc = NoteItem(
                id: contentItem.id,
                x: layoutOffset.dx,
                y: layoutOffset.dy,
                width: contentItem.width,
                height: contentItem.height,
                zIndex: contentItem.zIndex,
              );
              finalContentTargetPosition = calculateAwayPosition(
                tempBoardItemForCalc,
                openingNoteInstance,
                context,
              );
              finalContentAnimationDuration = noteOpenAnimationDuration;
              finalItemOpacity = 1.0;
              print(
                "Content ${contentItem.id}: External Note, Target AWAY: $finalContentTargetPosition",
              );
            } else {
              // No external note interference, animate based on this folder's state
              if (isThisFolderActuallyOpen) {
                finalContentTargetPosition = layoutOffset;
                finalContentAnimationDuration = const Duration(
                  milliseconds: 450,
                );
                finalItemAnimationCurve = Curves.easeOutCubic;
                finalItemOpacity = 1.0;
                print(
                  "Content ${contentItem.id}: Folder OPEN, Target LAYOUT: $finalContentTargetPosition",
                );
              } else {
                // Folder is closed
                finalContentTargetPosition = itemInitialPositionWithinFolder;
                finalContentAnimationDuration = const Duration(
                  milliseconds: 380,
                );
                finalItemAnimationCurve = Curves.easeInCubic;
                finalItemOpacity = 0.0;
                print(
                  "Content ${contentItem.id}: Folder CLOSED, Target INITIAL: $finalContentTargetPosition",
                );
              }
            }

            if (isThisFolderActuallyOpen && (currentlyOpeningNoteId == null || openingNoteInstance == null)) {
              currentFolderMinX = min(currentFolderMinX, layoutOffset.dx);
              currentFolderMinY = min(currentFolderMinY, layoutOffset.dy);
              currentFolderMaxX = max(currentFolderMaxX, layoutOffset.dx + contentItem.width);
              currentFolderMaxY = max(currentFolderMaxY, layoutOffset.dy + contentItem.height);
            }

            itemWidgetsToRender.add(
              AnimatedPositioned(
                key: ValueKey(
                  "content_${contentItem.id}_in_folder_${folder.id}",
                ),
                duration: finalContentAnimationDuration,
                curve: finalItemAnimationCurve,
                left: finalContentTargetPosition.dx,
                top: finalContentTargetPosition.dy,
                width: contentItem.width,
                height: contentItem.height,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: finalItemOpacity,
                  child: currentContentWidget,
                ),
              ),
            );
          });

            // Update openFolderBoundingBoxes for THIS folder
            const double padding = 20.0;
          if (isThisFolderActuallyOpen) {
            openFolderBoundingBoxes[folder.id] = Rect.fromLTRB(
              currentFolderMinX - padding,
              currentFolderMinY - padding,
              currentFolderMaxX + padding,
              currentFolderMaxY + padding,
            );
            print("BOUNDING BOX for POPULATED ${folder.id}: ${openFolderBoundingBoxes[folder.id]} (minX:$currentFolderMinX, minY:$currentFolderMinY, maxX:$currentFolderMaxX, maxY:$currentFolderMaxY)");

          } else { // Folder is NOT open
          openFolderBoundingBoxes.remove(folder.id);
          print("BOUNDING BOX for ${folder.id} REMOVED (folder not open)");
        }

      } else { // Folder's `contents` list is empty from the start
        if (isThisFolderActuallyOpen) {
          const double emptyFolderPadding = 10.0;
          openFolderBoundingBoxes[folder.id] = Rect.fromLTRB(
            folderIconTargetPosition.dx - emptyFolderPadding,
            folderIconTargetPosition.dy - emptyFolderPadding,
            folderIconTargetPosition.dx + folder.width + emptyFolderPadding,
            folderIconTargetPosition.dy + folder.height + emptyFolderPadding,
          );
          print("BOUNDING BOX for INITIALLY_EMPTY_AND_OPEN ${folder.id} (around icon): ${openFolderBoundingBoxes[folder.id]}");
        } else {
          openFolderBoundingBoxes.remove(folder.id);
          print("BOUNDING BOX for ${folder.id} REMOVED (initially empty and not open)");
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
      Duration animationDuration;

      if (justManipulatedIdFromNotifier == item.id) {
        animationDuration = itemDragSnapDuration;
      } else if (currentlyOpeningNoteId != null &&
          item.id != currentlyOpeningNoteId &&
          openingNoteInstance != null) {
        targetPosition = calculateAwayPosition(
          item,
          openingNoteInstance,
          context,
        );
        animationDuration = noteOpenAnimationDuration;
      } else if (currentlyOpeningNoteId == null) {
        animationDuration = noteCloseAnimationDuration;
      } else {
        animationDuration = defaultAnimationDuration; // Fallback
      }

      itemWidgetsToRender.add(
        AnimatedPositioned(
          // Top-level items are animated
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
      final bool isThisFolderCurrentlyOpen = openFolderIds.contains(folderId);
      bool folderIconIsVisible = true;
      if (currentlyOpeningNoteId != null && openingNoteInstance != null) {
        final folderItem = allSortedItems.firstWhere((it) => it.id == folderId);
        Offset folderTargetPos = calculateAwayPosition(
          folderItem,
          openingNoteInstance,
          context,
        );
        if ((folderTargetPos.dx - folderItem.x).abs() > 100 ||
            (folderTargetPos.dy - folderItem.y).abs() > 100) {
          folderIconIsVisible = false;
        }
      }
      finalRenderList.add(
          Positioned(
            key: ValueKey("positioned_bbox_$folderId"), // Key for the Positioned widget
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
          child: AnimatedOpacity(
            key: ValueKey("anim_opacity_bbox_$folderId"),
            duration: const Duration(milliseconds: 300),
            opacity: isThisFolderCurrentlyOpen && folderIconIsVisible ? 1.0 : 0.0,
            child: FolderBoundingBoxWidget(
              key: ValueKey("bbox_$folderId"),
              rect: rect,
            ),
          ),
        ),
      );
    });

    final List<Widget> boundingBoxWidgets = [];
    finalRenderList.addAll(boundingBoxWidgets);
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
            boardNotifier.itemWasJustManipulated(droppedItem.id);
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

          bool wasDirectBoardDrag = false;

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
              wasDirectBoardDrag = true;
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
              wasDirectBoardDrag = true;
            }
          }
          if (wasDirectBoardDrag) {
            boardNotifier.itemWasJustManipulated(droppedItem.id);
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
