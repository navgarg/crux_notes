import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note_item.dart';
import '../providers/board_providers.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteItem noteToEdit;

  const NoteEditorScreen({super.key, required this.noteToEdit});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _textController;
  late Color _currentNoteColor;
  late NoteItem _editableNote; // Local copy for editing

  @override
  void initState() {
    super.initState();
    _editableNote = widget.noteToEdit; // Initialize with the passed note
    _textController = TextEditingController(text: _editableNote.content);
    _currentNoteColor = _editableNote.color;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final updatedNote = NoteItem(
      id: _editableNote.id,
      x: _editableNote.x,
      y: _editableNote.y,
      width: _editableNote.width,
      height: _editableNote.height,
      zIndex: _editableNote.zIndex,
      content: _textController.text,
      color: _currentNoteColor,
      createdAt: _editableNote.createdAt, // Preserve original creation time
      updatedAt: Timestamp.now(), // Update modification time
    );
    ref.read(boardNotifierProvider.notifier).updateItem(updatedNote);
    Navigator.of(context).pop();
  }

  Color darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color lighten(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return hslLight.toColor();
  }

  void _pickColor() {
    Color pickerColor = _currentNoteColor; // Start with the current color

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (Color color) {
              pickerColor = color;
            },
            // enableAlpha: false,
            // displayThumbColor: true,
            pickerAreaHeightPercent: 0.5,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Select'),
            onPressed: () {
              setState(() {
                _currentNoteColor = pickerColor;
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine text color based on background luminance for better readability
    final Color textColor = _currentNoteColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    final Color fabBackgroundColor = _currentNoteColor.computeLuminance() > 0.5
        ? darken(_currentNoteColor, 0.15) // Darken light note colors
        : lighten(_currentNoteColor, 0.15); // Lighten dark note colors

    final Color fabForegroundColor = fabBackgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Scaffold(
      backgroundColor:
          _currentNoteColor, // Editor background matches note color
      appBar: AppBar(
        title: Text('Edit Note', style: TextStyle(color: textColor)),
        backgroundColor: _currentNoteColor.withAlpha(
          220,
        ), // Slightly transparent AppBar
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.color_lens, color: textColor),
            onPressed: _pickColor,
            tooltip: 'Change color',
          ),
        ],
      ),
      body: Hero(
        tag: 'note_hero_${widget.noteToEdit.id}',
        child: Material(
          type: MaterialType
              .transparency, // So the editor's own background shows through during transition
          child: Container(
            color:
                _currentNoteColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
              child: TextField(
                controller: _textController,
                expands: true,
                maxLines: null, // Allows infinite lines
                minLines: null,
                style: TextStyle(fontSize: 18, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Your note...',
                  hintStyle: TextStyle(
                    color: textColor.withAlpha(150),
                  ), // Hint text also adapts
                  border: InputBorder.none,
                ),
                autofocus: true,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveNote,
        icon: Icon(Icons.save, color: fabForegroundColor),
        label: Text('Save', style: TextStyle(color: fabForegroundColor)),
        backgroundColor: fabBackgroundColor,
        shape: StadiumBorder(
          side: BorderSide(color: _currentNoteColor.withAlpha(150), width: 1.5),
        ),
      ),
    );
  }
}
