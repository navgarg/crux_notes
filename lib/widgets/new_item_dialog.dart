import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/folder_item.dart';
import '../models/image_item.dart';
import '../models/note_item.dart';
import '../providers/board_providers.dart';

const _uuid = Uuid();

Future<void> showNewItemDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final boardNotifier = ref.read(boardNotifierProvider.notifier);

        return AlertDialog(
          title: const Text('Create New Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('Note'),
                onTap: () async {
                  final newNote = NoteItem(
                    id: _uuid.v4(),
                    x: 50,
                    y: 50,
                    zIndex: boardNotifier.getNextZIndex(),
                    content: 'New Note',
                    color: Colors.blueAccent, // Default color
                  );

                  await boardNotifier.addItem(newNote);
                  Navigator.of(dialogContext).pop(); // Close the dialog
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () async {
                  // todo: implement actual image picking from device/URL
                  final newImage = ImageItem(
                    id: _uuid.v4(),
                    x: 100,
                    y: 100,
                    zIndex: boardNotifier.getNextZIndex(),
                    imageUrl:
                    'https://picsum.photos/seed/${_uuid.v4().substring(0, 8)}/200/200',
                  );
                  await boardNotifier.addItem(newImage);
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('Folder'),
                onTap: () async {
                  final newFolder = FolderItem(
                    id: _uuid.v4(),
                    x: 150,
                    y: 150,
                    zIndex: boardNotifier.getNextZIndex(),
                    name: 'New Folder', // Default name
                  );
                  await boardNotifier.addItem(newFolder);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }