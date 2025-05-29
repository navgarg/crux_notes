
import 'package:cloud_firestore/cloud_firestore.dart';


// Enum to define the type of board item
enum BoardItemType { note, image, folder }

// Base class for all board items
abstract class BoardItem {
  final String id;
  double x; // Position on the board
  double y; // Position on the board
  double width;
  double height;
  final BoardItemType type;
  final Timestamp createdAt;
  Timestamp updatedAt;
  int zIndex; // For stacking order

  BoardItem({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
    required this.zIndex,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  })  : createdAt = createdAt ?? Timestamp.now(),
        updatedAt = updatedAt ?? Timestamp.now();

  // Method to convert to Firestore map
  Map<String, dynamic> toJson();

  // Common update method
  void updatePosition(double newX, double newY) {
    x = newX;
    y = newY;
    updatedAt = Timestamp.now();
  }

  void updateSize(double newWidth, double newHeight) {
    width = newWidth;
    height = newHeight;
    updatedAt = Timestamp.now();
  }
}