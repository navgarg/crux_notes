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

  @override
  Future<List<BoardItem>> build() async {
    final itemsCollection = ref.watch(userBoardItemsCollectionProvider);
    print("BoardNotifier: build() called. ItemsCollection: ${itemsCollection?.path}");

    if (itemsCollection == null) {
      return []; // No user, no collection, no items
    }

    try {
      final snapshot = await itemsCollection.get();
      // ... map snapshot ...
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) {
        final data = doc.data();

        final typeName = data['type'] as String? ?? 'note';
        final type = BoardItemType.values.firstWhere(
                (e) => e.name == typeName,
            orElse: () => BoardItemType.note
        );

        switch (type) {
          case BoardItemType.note:
            return NoteItem.fromJson(data);
          case BoardItemType.image:
            return ImageItem.fromJson(data);
          case BoardItemType.folder:
            return FolderItem.fromJson(data);
        }
      }).toList();
    } catch (e,s) {
      print("BoardNotifier: Error loading items from Firestore: $e\n$s");
      throw Exception("Failed to load board items: $e");
    }
  }

  Future<void> addItem(BoardItem item) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final currentItems = state.valueOrNull ?? [];
    state = AsyncData([...currentItems, item]);
    print('BoardNotifier: Added item locally: ${item.id}');

    try {
      await itemsCollection.doc(item.id).set(item.toJson());
      print("BoardNotifier: Item ${item.id} saved to Firestore.");
    } catch (e, s) {
      print("BoardNotifier: Error saving item ${item.id} to Firestore: $e\n$s");
      state = AsyncData(currentItems); // Revert
    }
  }

  Future<void> updateItem(BoardItem updatedItem) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final currentItems = state.valueOrNull ?? [];
    state = AsyncData(currentItems.map((i) => i.id == updatedItem.id ? updatedItem : i).toList());

    try {
      updatedItem.updatedAt = Timestamp.now();
      await itemsCollection.doc(updatedItem.id).update(updatedItem.toJson());
      print("BoardNotifier: Item ${updatedItem.id} updated.");
    } catch (e,s) {
      print("BoardNotifier: Error updating item ${updatedItem.id}: $e\n$s");
      state = AsyncData(currentItems); // Revert
    }
  }

  Future<void> setItemPosition(String itemId, double newX, double newY) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final currentItems = state.valueOrNull ?? [];
    BoardItem? itemToUpdate;
    final newItemsList = currentItems.map((item) {
      if (item.id == itemId) {
        itemToUpdate = _createUpdatedItemWithNewPosition(item, newX, newY);
        return itemToUpdate!;
      }
      return item;
    }).toList();

    state = AsyncData(newItemsList);

    if (itemToUpdate != null) {
      final BoardItem finalItemToUpdate = itemToUpdate!;
      try {
        await itemsCollection.doc(finalItemToUpdate.id).update(finalItemToUpdate.toJson());
        print("BoardNotifier: Item ${finalItemToUpdate.id} position updated.");
      } catch (e,s) {
        print("BoardNotifier: Error updating item ${finalItemToUpdate.id} position: $e\n$s");
        state = AsyncData(currentItems); // Revert
      }
    }
  }

  Future<void> bringToFront(String itemId) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final currentItems = state.valueOrNull ?? [];
    if (currentItems.isEmpty) return;

    int currentMaxZ = 0;
    for (final item in currentItems) { //find actual maxZ
      if (item.zIndex > currentMaxZ) {
        currentMaxZ = item.zIndex;
      }
    }
    final int newZIndex = currentMaxZ + 1;
    BoardItem? itemToUpdate; // Variable to hold the item that will be updated

    // Create the new list with the updated item
    final newItemsList = currentItems.map((item) {
      if (item.id == itemId) {
        itemToUpdate = _createUpdatedItemWithNewZIndex(item, newZIndex);
        return itemToUpdate!;
      }
      return item;
    }).toList();

    state = AsyncData(newItemsList);
    print('BoardNotifier: Brought item to front locally: $itemId with new zIndex $newZIndex');

    if (itemToUpdate != null) {
      final BoardItem finalItemToUpdate = itemToUpdate!;
      try {
        finalItemToUpdate.updatedAt = Timestamp.now();
        await itemsCollection.doc(finalItemToUpdate.id).update(finalItemToUpdate.toJson());
        print("BoardNotifier: Item ${finalItemToUpdate.id} zIndex updated in Firestore.");
      } catch (e,s) {
        print("BoardNotifier: Error updating item ${finalItemToUpdate.id} zIndex in Firestore: $e\n$s");
        state = AsyncData(currentItems); // Revert
      }
    }
  }

  BoardItem _createUpdatedItemWithNewPosition(BoardItem item, double newX, double newY) {
    final now = Timestamp.now();
    if (item is NoteItem) {
      return NoteItem(
          id: item.id,
          x: newX,
          y: newY,
          width: item.width,
          height: item.height,
          zIndex: item.zIndex,
          content: item.content,
          color: item.color,
          createdAt: item.createdAt,
          updatedAt: now);
    } else if (item is ImageItem) {
      return ImageItem(
          id: item.id,
          x: newX,
          y: newY,
          width: item.width,
          height: item.height,
          zIndex: item.zIndex,
          imageUrl: item.imageUrl,
          createdAt: item.createdAt,
          updatedAt: now);
    } else if (item is FolderItem) {
      return FolderItem(
          id: item.id,
          x: newX,
          y: newY,
          width: item.width,
          height: item.height,
          zIndex: item.zIndex,
          name: item.name,
          itemIds: item.itemIds,
          createdAt: item.createdAt,
          updatedAt: now);
    }
    throw Exception("Unknown item type in _createUpdatedItemWithNewPosition");
  }

  BoardItem _createUpdatedItemWithNewZIndex(BoardItem item, int newZIndex) {
    final now = Timestamp.now();
    if (item is NoteItem) {
      return NoteItem(
          id: item.id,
          x: item.x,
          y: item.y,
          width: item.width,
          height: item.height,
          zIndex: newZIndex,
          content: item.content,
          color: item.color,
          createdAt: item.createdAt,
          updatedAt: now);
    } else if (item is ImageItem) {
      return ImageItem(
          id: item.id,
          x: item.x,
          y: item.y,
          width: item.width,
          height: item.height,
          zIndex: newZIndex,
          imageUrl: item.imageUrl,
          createdAt: item.createdAt,
          updatedAt: now);
    } else if (item is FolderItem) {
      return FolderItem(
          id: item.id,
          x: item.x,
          y: item.y,
          width: item.width,
          height: item.height,
          zIndex: newZIndex,
          name: item.name,
          itemIds: item.itemIds,
          createdAt: item.createdAt,
          updatedAt: now);
    }
    throw Exception("Unknown item type in _createUpdatedItemWithNewZIndex");
  }

  int getNextZIndex() {
    final currentItems = state.valueOrNull ?? [];
    if (currentItems.isEmpty) return 0;
    int maxZ = currentItems.first.zIndex;
    for (var item in currentItems.skip(1)) {
      if (item.zIndex > maxZ) {
        maxZ = item.zIndex;
      }
    }
    return maxZ + 1;
  }
}