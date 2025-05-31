import 'package:crux_notes/widgets/new_item_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/board_item.dart';
import '../models/folder_item.dart';
import '../models/image_item.dart';
import '../models/note_item.dart';
import '../providers/auth_providers.dart';
import '../providers/board_providers.dart' hide firebaseAuthProvider;
import '../widgets/folder_widget.dart';
import '../widgets/image_widget.dart';
import '../widgets/note_widget.dart';
import 'note_editor_screen.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  // Helper method to show the dialog for creating new board items


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? currentUser = ref.watch(currentUserProvider);
    final AsyncValue<List<BoardItem>> asyncBoardItems = ref.watch(boardNotifierProvider);
    print("Building BoardScreen for user: ${currentUser?.email ?? 'Guest'}");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentUser != null ? '${currentUser.displayName ?? currentUser.email}\'s Board' : 'Board',
        ),
        actions: [
          if (currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref
                    .read(firebaseAuthProvider)
                    .signOut();
                // Invalidate the board provider to clear items and trigger re-fetch
                ref.invalidate(boardNotifierProvider);
              },
            ),
        ],
      ),
      body: asyncBoardItems.when(
        data: (boardItems) {
          if (currentUser == null) {
            return const Center(
              child: Text("Please log in to view your board."),
            );
          }
          // If no items, show empty state
          if (boardItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your board is empty.', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Tap the "New" button to add items.'),
                ],
              ),
            );
          }

          // Sort items by zIndex for correct visual stacking
          // Creating a new list for sorting to avoid modifying the provider's state list directly
          final sortedBoardItems = List<BoardItem>.from(boardItems)
            ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

          return DragTarget<BoardItem>(
            onWillAcceptWithDetails: (details) {
              // Accept any BoardItem being dragged
              return true;
            },
            onAcceptWithDetails: (details) {
              final BoardItem droppedItem = details.data;
              // Find the RenderBox of this DragTarget to convert global drop offset to local
              final RenderBox renderBox =
                  context.findRenderObject() as RenderBox;
              final Offset localOffset = renderBox.globalToLocal(
                details.offset,
              );

              final boardNotifier = ref.read(boardNotifierProvider.notifier);
              boardNotifier.updateItemGeometricProperties(
                droppedItem.id,
                newX: localOffset.dx,
                newY: localOffset.dy,
              );
              // Bring the dropped item to the front visually
              boardNotifier.bringToFront(droppedItem.id);
            },
            builder:
                (
                  BuildContext context,
                  List<BoardItem?> candidateData,
                  List<dynamic> rejectedData,
                ) {
                  return Stack(
                    children: sortedBoardItems.map<Widget>((BoardItem item) {
                      Widget itemWidget;
                      final Key itemKey = ValueKey(item.id);
                      if (item is NoteItem) {
                        itemWidget = NoteWidget(
                          key: itemKey,
                          note: item,
                          onTap: () {
                            print('Tapped note: ${item.id}');
                            Navigator.of(context).push(
                              MaterialPageRoute( // Basic navigation
                                builder: (context) => NoteEditorScreen(noteToEdit: item),
                              ),
                            );
                            // todo: replace with a custom PageRoute for animation
                          },
                        );
                      } else if (item is ImageItem) {
                        itemWidget = ImageWidget(
                          key: itemKey,
                          imageItem: item,
                        );
                      } else if (item is FolderItem) {
                        itemWidget = FolderWidget(
                          key: itemKey,
                          folder: item,
                          onTap: () {
                            print('Tapped folder: ${item.id}');
                            // todo: Implement folder opening
                          },
                        );
                      } else {
                        // Fallback for any unknown item types
                        itemWidget = Container(
                          key: itemKey,
                          child: Text('Unknown item type: ${item.runtimeType}'),
                        );
                      }

                      return Positioned(
                        left: item.x,
                        top: item.y,
                        child: Listener(
                          onPointerDown: (_) {
                            // Bring item to front when user starts interacting with it (e.g., before drag)
                            ref
                                .read(boardNotifierProvider.notifier)
                                .bringToFront(item.id);
                          },
                          child:
                              itemWidget,
                        ),
                      );
                    }).toList(),
                  );
                },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print("Error rendering BoardScreen: $error\n$stackTrace");
          return Center(
            child: Text('Oops! Something went wrong.\nError: $error'),
          );
        },
      ),
      floatingActionButton:
          currentUser !=
              null // Only show FAB if user is logged in
          ? FloatingActionButton.extended(
              onPressed: () => showNewItemDialog(context, ref),
              label: const Text('New'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }
}
