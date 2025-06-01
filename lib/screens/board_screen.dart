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

class BoardScreen extends ConsumerStatefulWidget {
  // Changed to ConsumerStatefulWidget
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

    final boardNotifier = ref.read(boardNotifierProvider.notifier);
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
            onWillAcceptWithDetails: (details) => true,
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
                          onPrimaryAction: () {
                            print('Tapped note: ${item.id}');
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    NoteEditorScreen(noteToEdit: item),
                              ),
                            );
                            // todo: replace with a custom PageRoute for animation
                          },
                        );
                      } else if (item is ImageItem) {
                        itemWidget = ImageWidget(key: itemKey, imageItem: item);
                      } else if (item is FolderItem) {
                        itemWidget = FolderWidget(
                          key: itemKey,
                          folder: item,
                          onPrimaryAction: () {
                            print('Primary action for folder: ${item.id}');
                            // todo: implement folder opening logic
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
                        // child: Listener(
                        //   onPointerDown: (_) {
                        //     // Bring item to front when user starts interacting with it (e.g., before drag)
                        //     ref
                        //         .read(boardNotifierProvider.notifier)
                        //         .bringToFront(item.id);
                        //   },
                        //   child: itemWidget,
                        // ),
                        child: itemWidget,
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
                    alignment:
                        Alignment.bottomRight,
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
