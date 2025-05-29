import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_item.dart';
import '../models/folder_item.dart';
import '../models/image_item.dart';
import '../models/note_item.dart';
import '../providers/board_providers.dart';
import '../widgets/folder_widget.dart';
import '../widgets/image_widget.dart';
import '../widgets/note_widget.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final boardItems = ref.watch(boardNotifierProvider);

    // Sort items by zIndex for correct stacking
    final sortedBoardItems = List<BoardItem>.from(boardItems)..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Get the AppBar height to adjust drop position if necessary
    final appBarHeight = AppBar().preferredSize.height;
    final screenPaddingTop = MediaQuery.of(context).padding.top;


    return Scaffold(
      appBar: AppBar(
        title: Text(user != null ? 'Board - ${user.displayName ?? user.email}' : 'Board'),
        actions: [ /* todo: add logout logic */ ],
      ),
      body: DragTarget<BoardItem>( // Wrap the Stack with DragTarget
        onWillAcceptWithDetails: (details) {
          //accept all board items for now
          return true;
        },
        onAcceptWithDetails: (details) {
          final BoardItem droppedItem = details.data;
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.offset);

          double newX = localOffset.dx;
          double newY = localOffset.dy;

          print('Item ${droppedItem.id} dropped at global ${details.offset}, local $localOffset');

          // Call the notifier method to update position
          ref.read(boardNotifierProvider.notifier).setItemPosition(
            droppedItem.id,
            newX, // Pass new absolute X
            newY, // Pass new absolute Y
          );

          // Also bring the dropped item to the front
          ref.read(boardNotifierProvider.notifier).bringToFront(droppedItem.id);
        },
        builder: (context, candidateData, rejectedData) {
          // candidateData is a list of data from Draggables currently hovering over this target.
          // rejectedData is a list of data from Draggables that were rejected by onWillAccept.
          return Stack(
            children: sortedBoardItems.map<Widget>((BoardItem item) {
              Widget itemWidget;
              Key itemKey = ValueKey(item.id);

              if (item is NoteItem) {
                itemWidget = NoteWidget(key: itemKey, note: item, onTap: () { /* ... */ });
              } else if (item is ImageItem) {
                itemWidget = ImageWidget(key: itemKey, imageItem: item, onTap: () { /* ... */ });
              } else if (item is FolderItem) {
                itemWidget = FolderWidget(key: itemKey, folder: item, onTap: () { /* ... */ });
              } else {
                itemWidget = Container(key: itemKey, child: Text('Unknown item type'));
              }

              return Positioned(
                left: item.x,
                top: item.y,
                child: Listener( // Listener to detect tap down to bring item to front
                  onPointerDown: (event) {
                    ref.read(boardNotifierProvider.notifier).bringToFront(item.id);
                  },
                  child: itemWidget,
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {  },
        label: Text(""),
      ),
    );
  }
}