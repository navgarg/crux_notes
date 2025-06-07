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
    double screenWidth,
    {
      double screenEdgePadding = 20.0,
      double contentStartOffsetX = 30.0, // From folder's right edge
      double itemMarginHorizontal = 15.0,
      double itemMarginVertical = 15.0,
      int preferredItemsPerRow = 3,
    }
    ) {
  final Map<String, Offset> layouts = {};
  if (folderContents.isEmpty) {
    return FolderContentLayout(itemOffsets: {}, totalWidth: 0, totalHeight: 0);
  }

  // Determine initial X for content, ensuring it's within screen bounds
  double initialContentX = folder.x + folder.width + contentStartOffsetX;
  if (folderContents.first.width > 0) { // Avoid issues if first item has 0 width
    initialContentX = min(initialContentX, screenWidth - screenEdgePadding - folderContents.first.width);
  }
  initialContentX = max(initialContentX, screenEdgePadding); // Respect left screen padding

  double currentX = initialContentX;
  double currentRelativeY = 0;         // Y offset from the top of the content area (folder.y)
  List<double> currentRowMaxHeights = [0]; // Max height of items in the current row being built
  int itemsInCurrentRow = 0;
  double contentBlockActualWidth = 0;  // To store the actual max width of the content block

  for (int i = 0; i < folderContents.length; i++) {
    final item = folderContents[i];
    bool moveToNextRow = false;

    // Check if we need to move to the next row before placing the current item
    if (itemsInCurrentRow > 0) { // Only check if it's not the first item in a (potential) new row
      // Adding this item would overflow the screen width
      if ((currentX + item.width) > (screenWidth - screenEdgePadding)) {
        moveToNextRow = true;
      }
      // Already reached preferred number of items per row (and not already wrapping due to screen width)
      if (!moveToNextRow && itemsInCurrentRow >= preferredItemsPerRow) {
        moveToNextRow = true;
      }
    }

    if (moveToNextRow) {
      currentRelativeY += currentRowMaxHeights.last + itemMarginVertical; // Move Y down
      currentX = initialContentX;        // Reset X to the start of the row
      itemsInCurrentRow = 0;             // Reset item count for the new row
      currentRowMaxHeights.add(0);       // Start tracking max height for this new row
    }

    // Store the layout for the current item
    // Y is folder.y (anchor) + currentRelativeY (accumulated height of previous rows)
    layouts[item.id] = Offset(currentX, folder.y + currentRelativeY);

    // Update the maximum height for the current row
    currentRowMaxHeights[currentRowMaxHeights.length - 1] =
        max(currentRowMaxHeights.last, item.height);

    // Update the actual width of the content block
    contentBlockActualWidth = max(contentBlockActualWidth, (currentX + item.width) - initialContentX);

    // Advance X for the next item in the same row
    currentX += item.width + itemMarginHorizontal;
    itemsInCurrentRow++;
  }

  // Calculate total height of the content block
  double totalContentBlockHeight = 0;
  if (folderContents.isNotEmpty && currentRowMaxHeights.isNotEmpty) {
    // total height is the Y offset of the last row + height of the last row
    totalContentBlockHeight = currentRelativeY + currentRowMaxHeights.last;
  }

  Map<String, Offset> finalLayouts = layouts; // Use original layouts by default
  if (totalContentBlockHeight > 0) { // Only adjust if there's content
    final double folderCenterY = folder.y + folder.height / 2;
    // The content block starts at folder.y + 0 (conceptually)
    final double contentBlockCenterY = folder.y + (totalContentBlockHeight / 2);
    final double verticalAdjustment = folderCenterY - contentBlockCenterY;

    Map<String, Offset> adjustedLayouts = {}; // Create a new map for adjusted layouts
    layouts.forEach((id, offset) {
      adjustedLayouts[id] = Offset(offset.dx, offset.dy + verticalAdjustment);
    });
    finalLayouts = adjustedLayouts;
  }

  return FolderContentLayout(
    itemOffsets: finalLayouts,
    totalWidth: contentBlockActualWidth,
    totalHeight: totalContentBlockHeight,
  );
}
