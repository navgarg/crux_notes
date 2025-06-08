import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
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
                  color: Colors.amber, // Default color
                );

                await boardNotifier.addItem(newNote);
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () async {
                print(
                  "Image tile tapped. Attempting to open file picker...",
                ); // Add a print statement
                try {
                  // 1. Pick an image file from the device
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );
                  print("File picker result: $result");

                  if (result == null || result.files.single.path == null) {
                    print("User cancelled the picker.");
                    return; // User canceled the picker
                  }

                  // Close the dialog immediately
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Processing image...')),
                  );

                  try {
                    final filePath = result.files.single.path!;

                    // Read the file into memory as bytes
                    final imageBytes = await File(filePath).readAsBytes();

                    // Decode the bytes into an image object using the 'image' package
                    img.Image? originalImage = img.decodeImage(imageBytes);
                    if (originalImage == null) {
                      throw Exception("Could not decode image file.");
                    }

                    // Resize the image to a reasonable size to fit in Firestore
                    img.Image resizedImage = img.copyResize(
                      originalImage,
                      width: 800,
                    );

                    // Re-encode the resized image into JPEG format (which is smaller than PNG)
                    final resizedBytes = img.encodeJpg(
                      resizedImage,
                      quality: 85,
                    );

                    // Convert the final bytes into a Base64 text string
                    final String base64String = base64Encode(resizedBytes);

                    if (base64String.length * 0.75 > 950000) {
                      // Check if it's over ~950KB
                      throw Exception(
                        "Image is too large to save. Please select a smaller one.",
                      );
                    }

                    // Create the ImageItem with the Base64 string
                    final boardNotifier = ref.read(
                      boardNotifierProvider.notifier,
                    );
                    final newImage = ImageItem(
                      id: _uuid.v4(),
                      x: 100,
                      y: 100,
                      zIndex: boardNotifier.getNextZIndex(),
                      imageBase64: base64String,
                    );

                    // Add the item to the board
                    await boardNotifier.addItem(newImage);

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image added!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding image: ${e.toString()}'),
                      ),
                    );
                  }
                } catch (e, s) {
                  // Catch the error AND the stack trace
                  print("AN ERROR OCCURRED: $e");
                  print("STACK TRACE: $s");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('A critical error occurred: $e')),
                  );
                }
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
