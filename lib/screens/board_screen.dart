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

    return Scaffold(
      appBar: AppBar(
        title: Text(user != null ? 'Board - ${user.displayName ?? user.email}' : 'Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Stack( // Use Stack for positioning items
        children: sortedBoardItems.map((item) {
          Widget itemWidget;
          if (item is NoteItem) {
            itemWidget = NoteWidget(
              note: item,
              onTap: () {
                print('Tapped note: ${item.id}');
                // TODO: Implement note expansion
              },
            );
          } else if (item is ImageItem) {
            itemWidget = ImageWidget(
              imageItem: item,
              onTap: () {
                print('Tapped image: ${item.id}');
                // Does nothing
              },
            );
          } else if (item is FolderItem) {
            itemWidget = FolderWidget(
              folder: item,
              onTap: () {
                print('Tapped folder: ${item.id}');
                // TODO: Implement folder opening
              },
            );
          } else {
            itemWidget = Container(child: Text('Unknown item type'));
          }

          return Positioned(
            left: item.x,
            top: item.y,
            width: item.width,
            height: item.height,
            child: itemWidget,
          );
        }).toList(),
      ),
    );
  }
}