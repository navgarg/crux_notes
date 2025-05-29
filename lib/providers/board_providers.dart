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

// --- Global/Helper instances ---
const _uuid = Uuid();

// --- Providers for external services (can also be annotated with @riverpod if preferred) ---
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

// --- BoardNotifier using @riverpod annotation ---
// The state type is List<BoardItem>.
@riverpod
class BoardNotifier extends _$BoardNotifier {
  // Extends the generated _$BoardNotifier

  @override
  List<BoardItem> build() {
    return _getMockItems(); // Initialize with mock data
  }

  List<BoardItem> _getMockItems() {
    // final user = ref.read(firebaseAuthProvider).currentUser;
    return [
      NoteItem(id: _uuid.v4(),
          x: 50,
          y: 50,
          zIndex: 0,
          content: 'Mock Note 1',
          color: Colors.lightBlueAccent),
      NoteItem(id: _uuid.v4(),
          x: 250,
          y: 100,
          zIndex: 1,
          content: 'Mock Note 2: A bit longer to test text wrapping and overflow.',
          color: Colors.pinkAccent),
      ImageItem(id: _uuid.v4(),
          x: 100,
          y: 250,
          zIndex: 0,
          imageUrl: 'https://picsum.photos/seed/boardimage/200/300'),
      FolderItem(id: _uuid.v4(),
          x: 400,
          y: 200,
          zIndex: 0,
          name: 'Mock Folder'),
    ];
  }

  // --- Methods to mutate the state ---

  void addItem(BoardItem item) {
    state = [...state, item];
    print('Added item: ${item.id}, type: ${item.type.name}, new zIndex: ${item
        .zIndex}');

    // await _saveItemToFirestore(item);
  }

  void updateItem(BoardItem updatedItem) {
    state = state.map((item) {
      return item.id == updatedItem.id ? updatedItem : item;
    }).toList();
    print('Updated item: ${updatedItem.id}');

    // await _updateItemInFirestore(updatedItem);
  }

  void updateItemPosition(String itemId, double dx, double dy) {
    state = state.map((item) {
      if (item.id == itemId) {
        // Create a new instance of the item with updated position
        if (item is NoteItem) {
          return NoteItem(
            id: item.id,
            x: item.x + dx,
            y: item.y + dy,
            width: item.width,
            height: item.height,
            zIndex: item.zIndex,
            content: item.content,
            color: item.color,
            createdAt: item.createdAt,
            updatedAt: Timestamp.now(),
          );
        } else if (item is ImageItem) {
          return ImageItem(
            id: item.id,
            x: item.x + dx,
            y: item.y + dy,
            width: item.width,
            height: item.height,
            zIndex: item.zIndex,
            imageUrl: item.imageUrl,
            createdAt: item.createdAt,
            updatedAt: Timestamp.now(),
          );
        }
        else if (item is FolderItem) {
          return FolderItem(
            id: item.id,
            x: item.x + dx,
            y: item.y + dy,
            width: item.width,
            height: item.height,
            zIndex: item.zIndex,
            name: item.name,
            itemIds: item.itemIds,
            createdAt: item.createdAt,
            updatedAt: Timestamp.now(),
          );
        }
      }
      return item;
    }).toList();
  }

  void bringToFront(String itemId) {
    if (state.isEmpty) return;

    int currentMaxZ = 0;
    for (final item in state) {
      if (item.zIndex > currentMaxZ) {
        currentMaxZ = item.zIndex;
      }
    }
    final int newZIndex = currentMaxZ + 1;

    state = state.map((item) {
      if (item.id == itemId) {
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
            // Assign new zIndex
            createdAt: item.createdAt,
            updatedAt: Timestamp.now(),
          );
        } else if (item is ImageItem) {
          return ImageItem(
            id: item.id,
            x: item.x,
            y: item.y,
            width: item.width,
            height: item.height,
            zIndex: newZIndex,
            imageUrl: item.imageUrl,
            // Assign new zIndex
            createdAt: item.createdAt,
            updatedAt: Timestamp.now(),
          );
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
            // Assign new zIndex
            createdAt: item.createdAt,
            updatedAt: Timestamp.now(),
          );
        }
      }
      return item;
    }).toList();
    print('Brought item to front: $itemId with new zIndex $newZIndex');
  }


  int getNextZIndex() {
    if (state.isEmpty) return 0;
    int maxZ = state.first.zIndex;
    for (var item in state) {
      if (item.zIndex > maxZ) {
        maxZ = item.zIndex;
      }
    }
    return maxZ + 1;
  }
}