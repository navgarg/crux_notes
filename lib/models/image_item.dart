import 'package:cloud_firestore/cloud_firestore.dart';

import 'board_item.dart';

class ImageItem extends BoardItem {
  // String imageUrl; // URL of the image (from Firebase Storage or web)
  String imageBase64;

  ImageItem({
    required super.id,
    required super.x,
    required super.y,
    super.width = 200, // Default width
    super.height = 200, // Default height
    required super.zIndex,
    // required this.imageUrl,
    required this.imageBase64,
    super.createdAt,
    super.updatedAt,
  }) : super(type: BoardItemType.image);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'type': type.name,
      'imageBase64': imageBase64,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'zIndex': zIndex,
    };
  }

  factory ImageItem.fromJson(Map<String, dynamic> json) {
    return ImageItem(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      imageBase64: json['imageBase64'] as String? ?? '',
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
      zIndex: json['zIndex'] as int? ?? 0,
    );
  }

  ImageItem copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    String? imageBase64,
    Timestamp? updatedAt,
  }) {
    return ImageItem(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      updatedAt: updatedAt ?? this.updatedAt,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }
}
