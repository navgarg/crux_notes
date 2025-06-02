import 'dart:math';

import 'package:crux_notes/utils/board_layout_utils.dart';
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
import '../widgets/board_view_widget.dart';
import '../widgets/folders/folder_widget.dart';
import '../widgets/images/image_widget.dart';
import '../widgets/note_widget.dart';
import 'note_editor_screen.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  bool _isDraggingOverFabForFolderCreation = false;

  //todo: make a prettier app bar. check spacing for logout button; add button to switch theme (or make profile)
  @override
  Widget build(BuildContext context) {
    final User? currentUser = ref.watch(currentUserProvider);
    final AsyncValue<List<BoardItem>> asyncBoardItems = ref.watch(
      boardNotifierProvider,
    );
    print("Building BoardScreen for user: ${currentUser?.email ?? 'Guest'}");

    final Set<String> selectedItemIds = ref.watch(
      boardNotifierProvider.select(
        (state) => state.valueOrNull != null
            ? ref.read(boardNotifierProvider.notifier).selectedItemIds
            : const <String>{},
      ),
    );
    final bool isAnythingSelected = selectedItemIds.isNotEmpty;

    Color fabBackgroundColor;
    Color fabForegroundColor; // For icon and text
    Widget fabIconWidget;
    String fabLabel;
    VoidCallback? fabAction = () =>
        showNewItemDialog(context, ref); // Default action

    final ColorScheme currentColorScheme = Theme.of(context).colorScheme;

    if (_isDraggingOverFabForFolderCreation && isAnythingSelected) {
      // State: Dragging selected items over/near FAB to create folder
      fabBackgroundColor =
          Colors.green.shade300; // A distinct "drop target" color
      fabForegroundColor = Colors.black87; // Ensure contrast
      fabIconWidget = const Icon(Icons.create_new_folder_outlined);
      fabLabel = "Create Folder";
      fabAction = null; // Action is on drop (onAcceptWithDetails)
    } else if (isAnythingSelected) {
      // State: Items are selected, FAB offers to clear selection
      fabBackgroundColor =
          currentColorScheme.secondaryContainer; // Use a theme color
      fabForegroundColor = currentColorScheme
          .onSecondaryContainer; // Contrasting text/icon color
      fabIconWidget = const Icon(Icons.deselect_outlined); // Changed icon
      fabLabel = "Clear (${selectedItemIds.length})";
      fabAction = () {
        ref.read(boardNotifierProvider.notifier).clearSelection();
      };
    } else {
      // State: Normal "New" item creation
      fabBackgroundColor =
          currentColorScheme.primaryContainer; // Use a theme color
      fabForegroundColor =
          currentColorScheme.onPrimaryContainer; // Contrasting text/icon color
      fabIconWidget = const Icon(Icons.add);
      fabLabel = "New";
      // fabAction is already set to _showCreateItemDialog
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentUser != null
              ? '${currentUser.displayName ?? currentUser.email}\'s Board'
              : 'Board',
        ),
        actions: [
          if (currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(firebaseAuthProvider).signOut();
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

          final openFolderIds = ref
              .watch(boardNotifierProvider.notifier)
              .openFolderIds;
          final openFolderContentsMap = ref
              .watch(boardNotifierProvider.notifier)
              .openFolderContents;

          // If no items, show empty state
          if (boardItems.isEmpty && openFolderIds.isEmpty) {
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

          print("BoardScreen: All Board Items Count: ${boardItems.length}");
          print("BoardScreen: Open Folder IDs: $openFolderIds");
          print(
            "BoardScreen: Open Folder Contents Map: ${openFolderContentsMap.map((k, v) => MapEntry(k, v.length))}",
          );

          return BoardViewWidget(
            boardItems: boardItems,
            openFolderIds: openFolderIds,
            // openFolderContentsMap: openFolderContentsMap, // Not strictly needed by BoardViewWidget anymore
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
      floatingActionButton: currentUser != null
          ? SizedBox(
              width: 150 + 100,
              height: 56 + 80,
              // color: Colors.transparent,
              // alignment: Alignment.bottomRight,
              child: DragTarget<BoardItem>(
                // FAB is also a DragTarget
                onWillAcceptWithDetails: (details) {
                  // Accept if items are selected and the dragged item is part of selection
                  bool accept =
                      isAnythingSelected &&
                      selectedItemIds.contains(details.data.id);
                  if (accept != _isDraggingOverFabForFolderCreation) {
                    setState(() {
                      _isDraggingOverFabForFolderCreation = accept;
                    });
                  }
                  return accept;
                },
                onMove: (details) {
                  final bool currentDraggableIsSelected = selectedItemIds
                      .contains(details.data.id);
                  if (isAnythingSelected &&
                      currentDraggableIsSelected &&
                      !_isDraggingOverFabForFolderCreation) {
                    setState(() {
                      _isDraggingOverFabForFolderCreation = true;
                    });
                  }
                },
                onLeave: (data) {
                  // When item is dragged away from FAB
                  if (_isDraggingOverFabForFolderCreation) {
                    setState(() {
                      _isDraggingOverFabForFolderCreation = false;
                    });
                  }
                },
                onAcceptWithDetails: (details) async {
                  setState(() {
                    _isDraggingOverFabForFolderCreation =
                        false; // Reset on drop
                  });
                  await ref
                      .read(boardNotifierProvider.notifier)
                      .createFolderFromSelection("New Group");
                },
                builder: (context, candidateFabDropData, rejectedFabDropData) {
                  return Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.transparent,
                      ),
                      FloatingActionButton.extended(
                        onPressed: fabAction,
                        label: Text(
                          fabLabel,
                          style: TextStyle(color: fabForegroundColor),
                        ),
                        icon: fabIconWidget,
                        backgroundColor: fabBackgroundColor,
                        // To make it more obvious it's a drop target when _isDraggingOverFabForFolderCreation:
                        elevation: _isDraggingOverFabForFolderCreation
                            ? 12.0
                            : 6.0,
                        shape: _isDraggingOverFabForFolderCreation
                            ? RoundedRectangleBorder(
                                side: BorderSide(
                                  color: Colors.green.shade700,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(28.0),
                              )
                            : null, // Default shape
                      ),
                    ],
                  );
                },
              ),
            )
          : null,
    );
  }
}
