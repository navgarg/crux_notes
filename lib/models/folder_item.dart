import 'package:cloud_firestore/cloud_firestore.dart';

import 'board_item.dart';

class FolderItem extends BoardItem {
  String name;
  List<String> itemIds; // List of IDs of notes/images contained in this folder

  FolderItem({
    required super.id,
    required super.x,
    required super.y,
    super.width = 180, // Default width
    super.height = 120, // Default height
    required super.zIndex,
    this.name = 'New Folder',
    this.itemIds = const [],
    super.createdAt,
    super.updatedAt,
  }) : super(type: BoardItemType.folder);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'type': type.name,
      'name': name,
      'itemIds': itemIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'zIndex': zIndex,
    };
  }

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      name: json['name'] as String? ?? 'Folder',
      itemIds: List<String>.from(json['itemIds'] as List<dynamic>? ?? []),
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
      zIndex: json['zIndex'] as int? ?? 0,
    );
  }

  FolderItem copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    String? name,
    List<String>? itemIds,
    Timestamp? updatedAt,
  }) {
    return FolderItem(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      createdAt: createdAt, // Keep original createdAt
      updatedAt: updatedAt ?? Timestamp.now(),
    );
  }
}