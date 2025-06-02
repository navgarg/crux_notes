import 'dart:math';

import '../models/board_item.dart';
import '../models/folder_item.dart';
import 'package:flutter/material.dart';

class FolderContentLayout {
  final Map<String, Offset> itemOffsets;
  final double totalWidth;
  final double totalHeight;

  FolderContentLayout({
    required this.itemOffsets,
    required this.totalWidth,
    required this.totalHeight,
  });
}

FolderContentLayout calculateFolderItemLayout(
    FolderItem folder,
    List<BoardItem> folderContents,
    ) {
  final Map<String, Offset> layouts = {};
  if (folderContents.isEmpty) {
    return FolderContentLayout(itemOffsets: {}, totalWidth: 0, totalHeight: 0);
  }

  final double itemMarginHorizontal = 15.0;
  final double itemMarginVertical = 15.0;
  final int itemsPerRow = 3;

  final double contentGridStartX = folder.x + folder.width + 30.0;

  List<double> rowHeights = [];
  double currentRelativeX = 0;
  double currentRowYOffset = 0;
  double maxGridWidth = 0;

  for (int i = 0; i < folderContents.length; i++) {
    final item = folderContents[i];
    if (i > 0 && i % itemsPerRow == 0) {
      currentRelativeX = 0;
      currentRowYOffset += rowHeights.last + itemMarginVertical;
      rowHeights.add(0);
    }
    if (rowHeights.isEmpty) rowHeights.add(0);

    rowHeights[rowHeights.length-1] = max(rowHeights.last, item.height);
    maxGridWidth = max(maxGridWidth, currentRelativeX + item.width);
    currentRelativeX += item.width + itemMarginHorizontal;
  }
  double totalContentGridHeight = rowHeights.isNotEmpty
      ? rowHeights.reduce((a,b) => a+b) + (itemMarginVertical * (rowHeights.length - 1).clamp(0, double.infinity))
      : 0;

  final double folderCenterY = folder.y + folder.height / 2;
  final double contentGridStartY = folderCenterY - (totalContentGridHeight / 2);

  currentRelativeX = 0;
  currentRowYOffset = 0;
  rowHeights.clear();

  for (int i = 0; i < folderContents.length; i++) {
    final item = folderContents[i];
    if (i > 0 && i % itemsPerRow == 0) {
      currentRelativeX = 0;
      currentRowYOffset += rowHeights.last + itemMarginVertical;
      rowHeights.add(0);
    }
    if (rowHeights.isEmpty) rowHeights.add(0);

    final double itemX = contentGridStartX + currentRelativeX;
    final double itemY = contentGridStartY + currentRowYOffset;
    layouts[item.id] = Offset(itemX, itemY);

    rowHeights[rowHeights.length-1] = max(rowHeights.last, item.height);
    currentRelativeX += item.width + itemMarginHorizontal;
  }

  return FolderContentLayout(
    itemOffsets: layouts,
    totalWidth: maxGridWidth,
    totalHeight: totalContentGridHeight,
  );
}