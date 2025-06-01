import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/board_item.dart';
import '../models/folder_item.dart';
import '../models/image_item.dart';
import '../models/note_item.dart';

part 'board_providers.g.dart';

Uuid _uuid = const Uuid();
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final userBoardItemsCollectionProvider = Provider<CollectionReference<Map<String, dynamic>>?>((ref) {
  final currentUser = ref.watch(firebaseAuthProvider).currentUser; // Watch auth state
  if (currentUser == null) {
    return null;
  }
  return ref.read(firestoreProvider)
      .collection('users')
      .doc(currentUser.uid)
      .collection('boardItems');
});


// The state type is List<BoardItem>.
@Riverpod(keepAlive: true) // Keep state alive even when no longer watched
class BoardNotifier extends _$BoardNotifier {
  // Extends the generated _$BoardNotifier

  final Set<String> _selectedItemIds = {};
  Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds); // Unmodifiable view


  @override
  Future<List<BoardItem>> build() async {
    _selectedItemIds.clear();
    final itemsCollection = ref.watch(userBoardItemsCollectionProvider);
    print("BoardNotifier: build() called. ItemsCollection path: ${itemsCollection?.path}");
    if (itemsCollection == null) return [];

    try {
      final snapshot = await itemsCollection.orderBy('zIndex').get(); // Good to order
      if (snapshot.docs.isEmpty) {
        print("BoardNotifier: No items found in Firestore. Returning empty list.");
        return [];
      }
      print("BoardNotifier: Loaded ${snapshot.docs.length} items from Firestore.");
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // The ID is part of the item's data if saved correctly by item.toJson()
        // If not, you'd do: data['id'] = doc.id;
        final typeName = data['type'] as String? ?? BoardItemType.note.name;
        final type = BoardItemType.values.firstWhere((e) => e.name == typeName, orElse: () => BoardItemType.note);
        switch (type) {
          case BoardItemType.note:   return NoteItem.fromJson(data);
          case BoardItemType.image:  return ImageItem.fromJson(data);
          case BoardItemType.folder: return FolderItem.fromJson(data);
        }
      }).toList();
    } catch (e, s) {
      print("BoardNotifier: Error loading items from Firestore: $e\n$s");
      throw Exception("Failed to load board items: $e");
    }
  }

  void toggleItemSelection(String itemId) {
    final currentItems = state.valueOrNull ?? [];
    if (_selectedItemIds.contains(itemId)) {
      _selectedItemIds.remove(itemId);
    } else {
      _selectedItemIds.add(itemId);
    }
    state = AsyncData(currentItems); // Re-emit to trigger UI update for selection visuals
    print("Selected IDs: $_selectedItemIds");
  }

  void clearSelection() {
    if (_selectedItemIds.isEmpty) return;
    _selectedItemIds.clear();
    state = AsyncData(state.valueOrNull ?? []);
    print("Selection cleared.");
  }

  Future<void> addItem(BoardItem item) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final currentItems = state.valueOrNull ?? [];
    state = AsyncData([...currentItems, item]); // Optimistic add

    try {
      await itemsCollection.doc(item.id).set(item.toJson());
      print("BoardNotifier: Item ${item.id} saved.");
    } catch (e, s) {
      print("BoardNotifier: Error saving item ${item.id}: $e\n$s");
      state = AsyncData(currentItems); // Revert optimistic add
    }
  }

  /// General method to update any properties of an item.
  Future<void> updateItem(BoardItem updatedItem) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final currentItems = state.valueOrNull ?? [];
    updatedItem.updatedAt = Timestamp.now();

    state = AsyncData(currentItems.map((item) {
      return item.id == updatedItem.id ? updatedItem : item;
    }).toList());
    print('BoardNotifier: Optimistically updated item: ${updatedItem.id}');

    try {
      await itemsCollection.doc(updatedItem.id).update(updatedItem.toJson());
      print("BoardNotifier: Item ${updatedItem.id} updated in Firestore.");
    } catch (e, s) {
      print("BoardNotifier: Error updating item ${updatedItem.id} in Firestore: $e\n$s");
      state = AsyncData(currentItems);
    }
  }


  /// Updates geometric properties (position, size, zIndex) of an item.
  Future<void> updateItemGeometricProperties(
      String itemId, {
        double? newX,
        double? newY,
        double? newWidth,
        double? newHeight,
        int? newZIndex,
      }) async {
    final currentItems = state.valueOrNull ?? [];
    final itemIndex = currentItems.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) {
      print("BoardNotifier: Item $itemId not found for geometric update.");
      return;
    }

    final originalItem = currentItems[itemIndex];
    BoardItem updatedItemInstance;
    final now = Timestamp.now();
    if (originalItem is NoteItem) {
      updatedItemInstance = NoteItem(
        id: originalItem.id,
        x: newX ?? originalItem.x, y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width, height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        content: originalItem.content, color: originalItem.color,
        createdAt: originalItem.createdAt, updatedAt: now,
      );
    }
    else if (originalItem is ImageItem) {
      updatedItemInstance = ImageItem(
        id: originalItem.id,
        x: newX ?? originalItem.x, y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width, height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        imageUrl: originalItem.imageUrl,
        createdAt: originalItem.createdAt, updatedAt: now,
      );
    }
    else if (originalItem is FolderItem) {
      updatedItemInstance = FolderItem(
        id: originalItem.id,
        x: newX ?? originalItem.x, y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width, height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        name: originalItem.name, itemIds: originalItem.itemIds,
        createdAt: originalItem.createdAt, updatedAt: now,
      );
    }
    else {
      print("BoardNotifier: Unknown item type for geometric update: ${originalItem.runtimeType}");
      return; // Or throw an error
    }

    await updateItem(updatedItemInstance);
  }

  Future<void> bringToFront(String itemId) async {
    final currentItems = state.valueOrNull ?? [];
    if (currentItems.isEmpty) return;

    int currentMaxZ = 0;
    for (final item in currentItems) {
      if (item.zIndex > currentMaxZ) {
        currentMaxZ = item.zIndex;
      }
    }
    final int newZIndexForFront = currentMaxZ + 1;

    await updateItemGeometricProperties(itemId, newZIndex: newZIndexForFront);
    print('BoardNotifier: Brought item to front: $itemId with new zIndex $newZIndexForFront');
  }

  int getNextZIndex() {
    final currentItems = state.valueOrNull ?? [];
    if (currentItems.isEmpty) return 0;
    int maxZ = 0; // Initialize to 0, as zIndex can't be less than 0
    for (var item in currentItems) {
      if (item.zIndex > maxZ) {
        maxZ = item.zIndex;
      }
    }
    return maxZ + 1;
  }

  Future<void> createFolderFromSelection(String folderName) async {
    if (_selectedItemIds.isEmpty) return;

    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final currentBoardItems = state.valueOrNull ?? [];
    if (currentBoardItems.isEmpty) return;

    // Find a position for the new folder (e.g., average of selected items, or fixed)
    // For simplicity, let's use a fixed offset or the position of the first selected item.
    double folderX = 100;
    double folderY = 100;
    BoardItem? firstSelectedItem;
    for(var item in currentBoardItems) {
      if(_selectedItemIds.contains(item.id)){
        firstSelectedItem = item;
        break;
      }
    }
    if(firstSelectedItem != null) {
      folderX = firstSelectedItem.x + 20; // Slightly offset
      folderY = firstSelectedItem.y + 20;
    }


    final newFolder = FolderItem(
      id: _uuid.v4(),
      x: folderX,
      y: folderY,
      name: folderName,
      itemIds: List.from(_selectedItemIds), // Copy the selected IDs
      zIndex: getNextZIndex(), // Place it on top
    );

    final itemsToKeepOnBoard = currentBoardItems.where((item) => !_selectedItemIds.contains(item.id)).toList();

    state = AsyncData([...itemsToKeepOnBoard, newFolder]);

    await _saveItemToFirestore(newFolder);

    for (String itemIdToRemove in _selectedItemIds) {
      try {
        await itemsCollection.doc(itemIdToRemove).delete();
        print("BoardNotifier: Deleted item $itemIdToRemove from board (moved to folder).");
      } catch (e) {
        print("BoardNotifier: Error deleting item $itemIdToRemove: $e");
      }
    }

    _selectedItemIds.clear();
  }

  Future<void> _saveItemToFirestore(BoardItem item) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) {
      print("BoardNotifier: User not logged in. Cannot save item ${item.id}.");
      return;
    }
    try {
      await itemsCollection.doc(item.id).set(item.toJson());
      print("BoardNotifier: Item ${item.id} saved to Firestore (from _saveItemToFirestore helper).");
    } catch (e, s) {
      print("BoardNotifier: Error saving item ${item.id} to Firestore (from helper): $e\n$s");
    }
  }

}