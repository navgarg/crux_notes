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
import '../providers/theme_provider.dart';
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
    final ThemeMode currentThemeMode = ref.watch(themeNotifierProvider); // Watch the theme mode
    final themeNotifier = ref.read(themeNotifierProvider.notifier);

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
      fabBackgroundColor = Colors.green.shade300;
      fabForegroundColor = Colors.black87;
      fabIconWidget = const Icon(Icons.create_new_folder_outlined);
      fabLabel = "Create Folder";
      fabAction = null;
    } else if (isAnythingSelected) {
      // State: Items are selected, FAB offers to clear selection
      fabBackgroundColor =
          currentColorScheme.secondaryContainer;
      fabForegroundColor = currentColorScheme
          .onSecondaryContainer;
      fabIconWidget = const Icon(Icons.deselect_outlined);
      fabLabel = "Clear Selection (${selectedItemIds.length})";
      fabAction = () {
        ref.read(boardNotifierProvider.notifier).clearSelection();
      };
    } else {
      fabBackgroundColor =
          currentColorScheme.primaryContainer;
      fabForegroundColor =
          currentColorScheme.onPrimaryContainer;
      fabIconWidget = const Icon(Icons.add);
      fabLabel = "New";
    }

    List<bool> isSelected = [false, false];
    final Brightness platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

    if (currentThemeMode == ThemeMode.light || (currentThemeMode == ThemeMode.system && platformBrightness == Brightness.light)) {
      isSelected = [true, false]; // Light mode is active
    } else { // Dark mode is active
      isSelected = [false, true];
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentUser != null
              ? '${currentUser.displayName ?? currentUser.email}\'s Board'
              : 'Board',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ToggleButtons(
              isSelected: isSelected,
              onPressed: (int index) {
                if (index == 0) { // Light mode selected
                  themeNotifier.setThemeMode(ThemeMode.light);
                } else { // Dark mode selected
                  themeNotifier.setThemeMode(ThemeMode.dark);
                }
              },
              // Styling for the buttons
              borderRadius: BorderRadius.circular(20.0),
              selectedBorderColor: Theme.of(context).colorScheme.primary,
              selectedColor: Theme.of(context).colorScheme.onPrimary, // Color of icon when selected
              fillColor: Theme.of(context).colorScheme.primary.withAlpha((255*0.8).round()), // Background when selected
              color: Theme.of(context).colorScheme.onSurface.withAlpha((255*0.7).round()), // Color of icon when not selected
              splashColor: Theme.of(context).colorScheme.primary.withAlpha((255*0.12).round()),
              hoverColor: Theme.of(context).colorScheme.primary.withAlpha((255*0.04).round()),
              constraints: const BoxConstraints(minHeight: 24.0, minWidth: 36.0),
              children: const <Widget>[
                Tooltip(
                  message: 'Light Theme',
                  child: Icon(Icons.light_mode_outlined, size: 20),
                ),
                Tooltip(
                  message: 'Dark Theme',
                  child: Icon(Icons.dark_mode_outlined, size: 20),
                ),
              ],
            ),
          ),
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
              child: DragTarget<BoardItem>(
                // onWillAcceptWithDetails: (details) {
                //   final data = details.data;
                //   bool accept = false;
                //   if (data is Set<String> && data.length > 1) {
                //     final currentlySelectedIdsFromNotifier = ref.read(boardNotifierProvider.notifier).selectedItemIds;
                //     if (currentlySelectedIdsFromNotifier.length == data.length &&
                //         currentlySelectedIdsFromNotifier.every((id) => data.contains(id))) {
                //       accept = true;
                //     }
                //   }
                //   if (accept != _isDraggingOverFabForFolderCreation) {
                //     WidgetsBinding.instance.addPostFrameCallback((_) {
                //       if (mounted) {
                //         setState(() => _isDraggingOverFabForFolderCreation = accept);
                //       }
                //     });
                //   }
                //   return accept;
                // },
                onWillAcceptWithDetails: (details) {
                  final boardNotifier = ref.read(boardNotifierProvider.notifier);

                  // The FAB should activate IF AND ONLY IF:
                  // 1. A group drag is active (the provider has a primary dragged item).
                  // 2. There is more than one item selected.
                  // 3. The item being dragged IS the primary item of that group.
                  final bool isGroupDragActive = boardNotifier.primaryDraggedItemIdForGroup != null &&
                      boardNotifier.selectedItemIds.length > 1 &&
                      boardNotifier.primaryDraggedItemIdForGroup == details.data.id;

                  // Update the UI state if needed
                  if (isGroupDragActive != _isDraggingOverFabForFolderCreation) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _isDraggingOverFabForFolderCreation = isGroupDragActive);
                      }
                    });
                  }
                  return isGroupDragActive;
                },

                // onMove: (details) {
                //   final data = details.data;
                //   bool shouldBeHovering = false;
                //   if (data is Set<String> && data.length>1) {
                //     final currentBoardItemsValue =
                //         ref.read(boardNotifierProvider).valueOrNull ?? [];
                //     bool containsFolder = data.any(
                //       (id) => currentBoardItemsValue.any(
                //         (bi) => bi.id == id && bi is FolderItem,
                //       ),
                //     );
                //     final currentlySelectedIdsFromNotifier = ref.read(boardNotifierProvider.notifier).selectedItemIds;
                //     if (currentlySelectedIdsFromNotifier.length == data.length &&
                //         currentlySelectedIdsFromNotifier.every((id) => data.contains(id)) && !containsFolder) {
                //       shouldBeHovering = true;
                //     }
                //     // else{
                //     //   const snackBar = SnackBar(content: Text('Cannot make folder with folders or only 1 item selected.'));
                //     //   ScaffoldMessenger.of(context).showSnackBar(snackBar);
                //     // }
                //   }
                //   if (shouldBeHovering != _isDraggingOverFabForFolderCreation) {
                //     WidgetsBinding.instance.addPostFrameCallback((_) {
                //       if (mounted)
                //         setState(
                //           () => _isDraggingOverFabForFolderCreation =
                //               shouldBeHovering,
                //         );
                //     });
                //   }
                // },
                onLeave: (data) {
                  if (_isDraggingOverFabForFolderCreation) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted)
                        setState(
                          () => _isDraggingOverFabForFolderCreation = false,
                        );
                    });
                  }
                },
                onAcceptWithDetails: (details) {
                  final boardNotifier = ref.read(boardNotifierProvider.notifier);

                  // Re-check the condition on accept for safety
                  final bool isGroupDragActive = boardNotifier.primaryDraggedItemIdForGroup != null &&
                      boardNotifier.selectedItemIds.length > 1 &&
                      boardNotifier.primaryDraggedItemIdForGroup == details.data.id;

                  if (isGroupDragActive) {
                    // The createFolderFromSelection function already knows which
                    // items are selected from the provider's internal state.
                    boardNotifier.createFolderFromSelection("New Group");
                  }

                  // Reset the UI state
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _isDraggingOverFabForFolderCreation = false);
                    }
                  });
                },

                builder:
                    (
                      BuildContext context,
                      List<Object?> candidateData,
                      List<dynamic> rejectedData,
                    ) {

                      // builder: (context, candidateFabDropData, rejectedFabDropData) {
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
