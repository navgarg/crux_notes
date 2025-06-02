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
    List<Widget> itemWidgetsToRender = [];
    Map<String, Rect> openFolderBoundingBoxes = {};
    Set<String> renderedAsFolderContentIds = {};

    final Set<String> allContainedItemIds = {};
    for (final item in boardItems) {
      if (item is FolderItem) {
        allContainedItemIds.addAll(item.itemIds);
      }
    }

    final allSortedItems = List<BoardItem>.from(boardItems)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Open folders and their contents
    for (final BoardItem item in allSortedItems) {
      if (item is FolderItem && openFolderIds.contains(item.id)) {
        final folder = item;
        itemWidgetsToRender.add(
          Positioned(
            key: ValueKey(folder.id), left: folder.x, top: folder.y,
            child: Listener(
              onPointerDown: (_) => ref.read(boardNotifierProvider.notifier).bringToFront(folder.id),
              child: FolderWidget(folder: folder),
            ),
          ),
        );

        final List<BoardItem> contents = boardItems.where((bi) => folder.itemIds.contains(bi.id)).toList();
        if (contents.isNotEmpty) {
          FolderContentLayout contentLayout = calculateFolderItemLayout(folder, contents);
          double minX = folder.x, minY = folder.y, maxX = folder.x + folder.width, maxY = folder.y + folder.height;

          contentLayout.itemOffsets.forEach((contentItemId, layoutOffset) {
            final contentItem = contents.firstWhere((ci) => ci.id == contentItemId);
            renderedAsFolderContentIds.add(contentItem.id);

            minX = min(minX, layoutOffset.dx); minY = min(minY, layoutOffset.dy);
            maxX = max(maxX, layoutOffset.dx + contentItem.width); maxY = max(maxY, layoutOffset.dy + contentItem.height);

            Widget currentContentWidget;
            if (contentItem is NoteItem) {
              currentContentWidget = NoteWidget(
                  key: ValueKey("content_${contentItem.id}"), note: contentItem,
                  onPrimaryAction: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteToEdit: contentItem)));
                  });
            } else if (contentItem is ImageItem) {
              currentContentWidget = ImageWidget(key: ValueKey("content_${contentItem.id}"), imageItem: contentItem);
            } else { return; }

            itemWidgetsToRender.add(
              Positioned(
                key: ValueKey("pos_content_${contentItem.id}"), left: layoutOffset.dx, top: layoutOffset.dy,
                child: Listener(
                  onPointerDown: (_) => ref.read(boardNotifierProvider.notifier).bringToFront(contentItem.id),
                  child: currentContentWidget,
                ),
              ),
            );
          });
          const double padding = 20.0;
          openFolderBoundingBoxes[folder.id] = Rect.fromLTRB(minX - padding, minY - padding, maxX + padding, maxY + padding);
        }
      }
    }

    // Top-level items
    for (final BoardItem item in allSortedItems) {
      if (item is FolderItem && openFolderIds.contains(item.id)) {
        continue;
      }
      if (allContainedItemIds.contains(item.id) && !renderedAsFolderContentIds.contains(item.id)) {
        continue;
      }
      if (renderedAsFolderContentIds.contains(item.id)) {
        continue;
      }

      Widget currentItemWidget;
      if (item is NoteItem) {
        currentItemWidget = NoteWidget(
            key: ValueKey(item.id), note: item,
            onPrimaryAction: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteToEdit: item)));
            });
      } else if (item is ImageItem) {
        currentItemWidget = ImageWidget(key: ValueKey(item.id), imageItem: item);
      } else if (item is FolderItem) { // Closed folder
        currentItemWidget = FolderWidget(key: ValueKey(item.id), folder: item);
      } else { continue; }

      itemWidgetsToRender.add(
        Positioned(
          key: ValueKey(item.id), left: item.x, top: item.y,
          child: Listener(
            onPointerDown: (_) => ref.read(boardNotifierProvider.notifier).bringToFront(item.id),
            child: currentItemWidget,
          ),
        ),
      );
    }

    List<Widget> finalRenderList = [];
    openFolderBoundingBoxes.forEach((folderId, rect) {
      finalRenderList.add(FolderBoundingBoxWidget(key: ValueKey("bbox_$folderId"), rect: rect));
    });
    finalRenderList.addAll(itemWidgetsToRender);

    return DragTarget<BoardItem>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final BoardItem droppedItem = details.data;
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset localOffset = renderBox.globalToLocal(details.offset);
        final boardNotifier = ref.read(boardNotifierProvider.notifier);
        boardNotifier.updateItemGeometricProperties(
          droppedItem.id,
          newX: localOffset.dx,
          newY: localOffset.dy,
        );
        boardNotifier.bringToFront(droppedItem.id);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(children: finalRenderList);
      },
    );
  }
}