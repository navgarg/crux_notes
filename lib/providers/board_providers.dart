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

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final userBoardItemsCollectionProvider =
    Provider<CollectionReference<Map<String, dynamic>>?>((ref) {
      final currentUser = ref
          .watch(firebaseAuthProvider)
          .currentUser; // Watch auth state
      if (currentUser == null) {
        return null;
      }
      return ref
          .read(firestoreProvider)
          .collection('users')
          .doc(currentUser.uid)
          .collection('boardItems');
    });

// The state type is List<BoardItem>.
@Riverpod(keepAlive: true) // Keep state alive even when no longer watched
class BoardNotifier extends _$BoardNotifier {
  // Extends the generated _$BoardNotifier

  List<BoardItem> get _currentItemsValue => state.valueOrNull ?? [];

  final Set<String> _selectedItemIds = {};
  Set<String> get selectedItemIds =>
      Set.unmodifiable(_selectedItemIds); // Unmodifiable view

  final Set<String> _openFolderIds = {};
  Set<String> get openFolderIds => Set.unmodifiable(_openFolderIds);

  final Map<String, List<BoardItem>> _openFolderContents = {};
  Map<String, List<BoardItem>> get openFolderContents =>
      Map.unmodifiable(_openFolderContents);

  String? _openingNoteId; // ID of the note currently being animated to open
  String? get openingNoteId => _openingNoteId;

  @override
  Future<List<BoardItem>> build() async {
    _selectedItemIds.clear();

    final itemsCollection = ref.watch(userBoardItemsCollectionProvider);
    print(
      "BoardNotifier: build() called. ItemsCollection path: ${itemsCollection?.path}",
    );

    if (itemsCollection == null) {
      _openFolderIds.clear(); // Clear open folders if user logs out
      _openFolderContents.clear();
      return [];
    }

    try {
      final snapshot = await itemsCollection.orderBy('zIndex').get();
      if (snapshot.docs.isEmpty) {
        print(
          "BoardNotifier: No items found in Firestore. Returning empty list.",
        );
        _openFolderIds.clear();
        _openFolderContents.clear();
        return [];
      }
      print(
        "BoardNotifier: Loaded ${snapshot.docs.length} items from Firestore.",
      );
      final allItems = snapshot.docs.map((doc) {
        final data = doc.data();
        final typeName = data['type'] as String? ?? BoardItemType.note.name;
        final type = BoardItemType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => BoardItemType.note,
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
      // await _repopulateOpenFolderContents(allItems);
      return allItems;
    } catch (e, s) {
      print("BoardNotifier: Error loading items from Firestore: $e\n$s");
      _openFolderIds.clear();
      _openFolderContents.clear();
      throw Exception("Failed to load board items: $e");
    }
  }

  void toggleItemSelection(String itemId) {
    final currentItems = state.valueOrNull ?? [];

    final item = _currentItemsValue.firstWhere((i) => i.id == itemId);
    if (item is FolderItem) {
      print("BoardNotifier: Folders cannot be selected for grouping.");
      return; // Prevent selecting folders
    }

    if (_selectedItemIds.contains(itemId)) {
      _selectedItemIds.remove(itemId);
    } else {
      _selectedItemIds.add(itemId);
    }
    state = AsyncData(
      currentItems,
    ); // Re-emit to trigger UI update for selection visuals
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

    final optimisticItems = [..._currentItemsValue, item];
    state = AsyncData(optimisticItems);

    try {
      await itemsCollection.doc(item.id).set(item.toJson());
      print("BoardNotifier: Item ${item.id} saved.");
    } catch (e, s) {
      print("BoardNotifier: Error saving item ${item.id}: $e\n$s");
      state = AsyncData(List.from(_currentItemsValue)); // Revert
    }
  }

  /// General method to update any properties of an item.
  Future<void> updateItem(BoardItem updatedItem) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    final originalItems = List<BoardItem>.from(
      _currentItemsValue,
    ); // For revert
    updatedItem.updatedAt = Timestamp.now();

    state = AsyncData(
      originalItems.map((item) {
        return item.id == updatedItem.id ? updatedItem : item;
      }).toList(),
    );

    try {
      await itemsCollection.doc(updatedItem.id).update(updatedItem.toJson());
      print("BoardNotifier: Item ${updatedItem.id} updated in Firestore.");
    } catch (e, s) {
      print(
        "BoardNotifier: Error updating item ${updatedItem.id} in Firestore: $e\n$s",
      );
      state = AsyncData(originalItems);
    }
  }

  /// Updates geometric properties (position, size, zIndex) of an item.
  Future<void> updateItemGeometricProperties(String itemId, {double? newX, double? newY, double? newWidth, double? newHeight, int? newZIndex,}) async {
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
        x: newX ?? originalItem.x,
        y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width,
        height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        content: originalItem.content,
        color: originalItem.color,
        createdAt: originalItem.createdAt,
        updatedAt: now,
      );
    } else if (originalItem is ImageItem) {
      updatedItemInstance = ImageItem(
        id: originalItem.id,
        x: newX ?? originalItem.x,
        y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width,
        height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        imageUrl: originalItem.imageUrl,
        createdAt: originalItem.createdAt,
        updatedAt: now,
      );
    } else if (originalItem is FolderItem) {
      updatedItemInstance = FolderItem(
        id: originalItem.id,
        x: newX ?? originalItem.x,
        y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width,
        height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        name: originalItem.name,
        itemIds: originalItem.itemIds,
        createdAt: originalItem.createdAt,
        updatedAt: now,
      );
    } else {
      print(
        "BoardNotifier: Unknown item type for geometric update: ${originalItem.runtimeType}",
      );
      return;
    }

    await updateItem(updatedItemInstance);
  }

  void updateItemGeometricPropertiesLocally(String itemId, {double? newX, double? newY, double? newWidth, double? newHeight, int? newZIndex,}) {
    final currentItems = _currentItemsValue;
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
        x: newX ?? originalItem.x,
        y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width,
        height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        content: originalItem.content,
        color: originalItem.color,
        createdAt: originalItem.createdAt,
        updatedAt: now,
      );
    } else if (originalItem is ImageItem) {
      updatedItemInstance = ImageItem(
        id: originalItem.id,
        x: newX ?? originalItem.x,
        y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width,
        height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        imageUrl: originalItem.imageUrl,
        createdAt: originalItem.createdAt,
        updatedAt: now,
      );
    } else if (originalItem is FolderItem) {
      updatedItemInstance = FolderItem(
        id: originalItem.id,
        x: newX ?? originalItem.x,
        y: newY ?? originalItem.y,
        width: newWidth ?? originalItem.width,
        height: newHeight ?? originalItem.height,
        zIndex: newZIndex ?? originalItem.zIndex,
        name: originalItem.name,
        itemIds: originalItem.itemIds,
        createdAt: originalItem.createdAt,
        updatedAt: now,
      );
    } else {
      print(
        "BoardNotifier: Unknown item type for geometric update: ${originalItem.runtimeType}",
      );
      return;
    }

    final newList = List<BoardItem>.from(currentItems);
    newList[itemIndex] = updatedItemInstance;
    state = AsyncData(newList); // Just update local state
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
    print(
      'BoardNotifier: Brought item to front: $itemId with new zIndex $newZIndexForFront',
    );
  }

  int getNextZIndex() {
    // final currentItems = state.valueOrNull ?? [];
    final items = _currentItemsValue;
    if (items.isEmpty) return 0;
    int maxZ = 0;
    for (var item in items) {
      if (item.zIndex > maxZ) {
        maxZ = item.zIndex;
      }
    }
    return maxZ + 1;
  }

  Future<void> createFolderFromSelection(String folderName) async {

    if (_selectedItemIds.isEmpty) {
      print("BoardNotifier: No items selected to create a folder.");
      return;
    }

    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) {
      print("BoardNotifier: User not logged in. Cannot create folder.");
      return;
    }

    final currentBoardItems = state.valueOrNull ?? [];
    if (currentBoardItems.isEmpty) return;
    if (currentBoardItems.isEmpty && _selectedItemIds.isNotEmpty) {
      print("BoardNotifier: Warning - selected items exist but board state is empty. Clearing selection.");
      _selectedItemIds.clear();
      return;
    }

    double folderX = 100;
    double folderY = 100;
    BoardItem? firstSelectedItem;

    firstSelectedItem = currentBoardItems.firstWhere(
            (item) => _selectedItemIds.contains(item.id),
        orElse: () {
          print("BoardNotifier: Warning - Could not find first selected item instance in current board items.");
          return currentBoardItems.isNotEmpty ? currentBoardItems.first : NoteItem(id:'temp', x:100, y:100, zIndex:0); // Temporary placeholder if board empty
        }
    );

    if(firstSelectedItem.id != 'temp') {
      folderX = firstSelectedItem.x + 20; // Slightly offset
      folderY = firstSelectedItem.y + 20;
    }

    final List<String> itemsToPutInFolder = List.from(_selectedItemIds);
    print("BoardNotifier: Creating folder with these item IDs: $itemsToPutInFolder");

    final newFolder = FolderItem(
      id: _uuid.v4(),
      x: folderX,
      y: folderY,
      name: folderName,
      itemIds: itemsToPutInFolder,
      zIndex: getNextZIndex(), // Place it on top
    );

    final optimisticBoardItemsList = [...currentBoardItems, newFolder];
    state = AsyncData(optimisticBoardItemsList);
    print('BoardNotifier: Optimistically added new folder ${newFolder.id}');

    try {
      await itemsCollection.doc(newFolder.id).set(newFolder.toJson());
      print("BoardNotifier: New folder ${newFolder.id} saved with itemIds: ${newFolder.itemIds}");
    } catch (e, s) {
      print("BoardNotifier: Error saving new folder ${newFolder.id} to Firestore: $e\n$s");
      state = AsyncData(List.from(currentBoardItems));
    }

    _selectedItemIds.clear();
    print("BoardNotifier: Selection cleared after folder creation.");
    // state = AsyncData(List.from(itemsToKeepOnBoard));
    state = AsyncData(List.from(optimisticBoardItemsList));
  }

  Future<void> toggleFolderOpenState(String folderId) async {
    final currentItems = _currentItemsValue;
    if (_openFolderIds.contains(folderId)) {
      _openFolderIds.remove(folderId);
    } else {
      _openFolderIds.add(folderId);
    }
    // Force a rebuild of listeners by re-emitting the main state
    state = AsyncData(List.from(currentItems));
    print(
      "BoardNotifier: Toggled folder $folderId. Open folders: $_openFolderIds",
    );
  }

  Future<void> persistItemGeometry(String itemId) async {
    final itemToPersist = _currentItemsValue.firstWhere((i) => i.id == itemId);
    await updateItemGeometricProperties(
      itemToPersist.id,
      newHeight: itemToPersist.height,
      newWidth: itemToPersist.width,
      newX: itemToPersist.x,
      newY: itemToPersist.y,
      newZIndex: itemToPersist.zIndex,
    );
    }

  String? _findParentFolderIdForItem(String itemId, List<BoardItem> allItems) {
    for (final item in allItems) {
      if (item is FolderItem && item.itemIds.contains(itemId)) {
        return item.id;
      }
    }
    return null;
  }

  Future<void> addItemToFolder(String targetFolderId, String itemIdToAdd) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    var currentItems = List<BoardItem>.from(state.valueOrNull ?? []);
    final targetFolderIndex = currentItems.indexWhere((f) => f.id == targetFolderId && f is FolderItem);

    if (targetFolderIndex == -1) {
      print("BoardNotifier: Target folder $targetFolderId not found to add item $itemIdToAdd");
      return;
    }
    FolderItem targetFolder = currentItems[targetFolderIndex] as FolderItem;

    final String? previousParentFolderId = _findParentFolderIdForItem(itemIdToAdd, currentItems);
    if (previousParentFolderId != null) {
      if (previousParentFolderId == targetFolderId) {
        print("BoardNotifier: Item $itemIdToAdd is already in target folder $targetFolderId.");
        return; // Already in the target folder
      }
      // Remove from previous folder
      final previousFolderIndex = currentItems.indexWhere((f) => f.id == previousParentFolderId && f is FolderItem);
      if (previousFolderIndex != -1) {
        FolderItem previousFolder = currentItems[previousFolderIndex] as FolderItem;
        final updatedPrevFolderItemIds = List<String>.from(previousFolder.itemIds)..remove(itemIdToAdd);
        currentItems[previousFolderIndex] = FolderItem(
          id: previousFolder.id, x: previousFolder.x, y: previousFolder.y, width: previousFolder.width, height: previousFolder.height,
          name: previousFolder.name, itemIds: updatedPrevFolderItemIds, zIndex: previousFolder.zIndex,
          createdAt: previousFolder.createdAt, updatedAt: Timestamp.now(),
        );
        print("BoardNotifier: Item $itemIdToAdd removed from previous folder $previousParentFolderId.");
      }
    }

    if (targetFolder.itemIds.contains(itemIdToAdd)) {
      print("BoardNotifier: Item $itemIdToAdd is already in target folder $targetFolderId (double check).");
      return;
    }
    final updatedTargetFolderItemIds = List<String>.from(targetFolder.itemIds)..add(itemIdToAdd);
    currentItems[targetFolderIndex] = FolderItem(
      id: targetFolder.id, x: targetFolder.x, y: targetFolder.y, width: targetFolder.width, height: targetFolder.height,
      name: targetFolder.name, itemIds: updatedTargetFolderItemIds, zIndex: targetFolder.zIndex,
      createdAt: targetFolder.createdAt, updatedAt: Timestamp.now(),
    );


    state = AsyncData(List.from(currentItems));

    try {
      final batch = FirebaseFirestore.instance.batch();
      if (previousParentFolderId != null && previousParentFolderId != targetFolderId) {
        final prevFolder = currentItems.firstWhere((it) => it.id == previousParentFolderId) as FolderItem;
        batch.update(itemsCollection.doc(previousParentFolderId), {'itemIds': prevFolder.itemIds, 'updatedAt': Timestamp.now()});
      }
      batch.update(itemsCollection.doc(targetFolderId), {'itemIds': updatedTargetFolderItemIds, 'updatedAt': Timestamp.now()});
      await batch.commit();
      print("BoardNotifier: Item $itemIdToAdd processed for folder $targetFolderId. Previous: $previousParentFolderId");
    } catch (e, s) {
      print("BoardNotifier: Error batch updating folders for adding item $itemIdToAdd: $e\n$s");
      ref.invalidateSelf();
    }
    clearSelection();
  }

  Future<void> removeItemFromFolder(String sourceFolderId, String itemIdToRemove, {double? newX, double? newY}) async {
    final itemsCollection = ref.read(userBoardItemsCollectionProvider);
    if (itemsCollection == null) return;

    var currentItems = List<BoardItem>.from(state.valueOrNull ?? []);
    final sourceFolderIndex = currentItems.indexWhere((f) => f.id == sourceFolderId && f is FolderItem);

    if (sourceFolderIndex == -1) {
      print("BoardNotifier: Source folder $sourceFolderId not found to remove item $itemIdToRemove");
      return;
    }
    FolderItem sourceFolder = currentItems[sourceFolderIndex] as FolderItem;

    if (!sourceFolder.itemIds.contains(itemIdToRemove)) {
      print("BoardNotifier: Item $itemIdToRemove is not in source folder $sourceFolderId.");
      return;
    }

    final updatedSourceFolderItemIds = List<String>.from(sourceFolder.itemIds)..remove(itemIdToRemove);
    currentItems[sourceFolderIndex] = FolderItem(
        id: sourceFolder.id, x: sourceFolder.x, y: sourceFolder.y, width: sourceFolder.width, height: sourceFolder.height,
        name: sourceFolder.name, itemIds: updatedSourceFolderItemIds, zIndex: sourceFolder.zIndex,
        createdAt: sourceFolder.createdAt, updatedAt: Timestamp.now()
    );

    final itemIndex = currentItems.indexWhere((i) => i.id == itemIdToRemove);
    BoardItem? updatedItemInstance;
    if (itemIndex != -1) {
      BoardItem item = currentItems[itemIndex];
      final now = Timestamp.now();
      if (item is NoteItem) {
        updatedItemInstance = item.copyWith(x: newX ?? item.x, y: newY ?? item.y, zIndex: getNextZIndex(), updatedAt: now);
      } else if (item is ImageItem) {
        updatedItemInstance = item.copyWith(x: newX ?? item.x, y: newY ?? item.y, zIndex: getNextZIndex(), updatedAt: now);
      }
      if (updatedItemInstance != null) {
        currentItems[itemIndex] = updatedItemInstance;
      }
    }

    state = AsyncData(List.from(currentItems));

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(itemsCollection.doc(sourceFolderId), {'itemIds': updatedSourceFolderItemIds, 'updatedAt': Timestamp.now()});
      if (updatedItemInstance != null && (newX != null || newY != null)) {
        batch.update(itemsCollection.doc(itemIdToRemove), updatedItemInstance.toJson());
      }
      await batch.commit();
      print("BoardNotifier: Item $itemIdToRemove removed from folder $sourceFolderId and updated.");
    } catch (e, s) {
      print("BoardNotifier: Error in batch update for removing $itemIdToRemove from folder: $e\n$s");
      ref.invalidateSelf();
    }

    clearSelection();
  }

  void setOpeningNoteId(String noteId) {
    _openingNoteId = noteId;
    final currentItems = List<BoardItem>.from(state.valueOrNull ?? []);
    state = AsyncData(currentItems);
  }

  void clearOpeningNoteId() {
    _openingNoteId = null;
    final currentItems = List<BoardItem>.from(state.valueOrNull ?? []);
    state = AsyncData(currentItems);
  }
}
