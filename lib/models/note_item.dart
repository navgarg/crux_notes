import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'board_item.dart';

class NoteItem extends BoardItem {
  String content;
  Color color; // Background color of the note

  NoteItem({
    required super.id,
    required super.x,
    required super.y,
    super.width = 150, // Default width
    super.height = 150, // Default height
    required super.zIndex,
    this.content = '',
    this.color = Colors.yellow, // Default color
    super.createdAt,
    super.updatedAt,
  }) : super(type: BoardItemType.note);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'type': type.name, // Store enum as string
      'content': content,
      'color': color.toARGB32(), // Store color as int
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'zIndex': zIndex,
    };
  }

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      content: json['content'] as String? ?? '',
      color: Color(json['color'] as int? ?? Colors.yellow as int),
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
      zIndex: json['zIndex'] as int? ?? 0,
    );
  }
  NoteItem copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    String? content,
    Color? color,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      content: content ?? this.content,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}