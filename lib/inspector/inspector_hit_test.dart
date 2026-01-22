import 'dart:math';

import 'package:flutter/material.dart';

import 'inspector_node.dart';

InspectorNode? findNodeAtOffset(List<InspectorNode> nodes, Offset position) {
  final hits = nodes.where((node) => node.rect.contains(position)).toList();
  if (hits.isEmpty) {
    return null;
  }

  hits.sort((a, b) {
    final areaA = a.rect.width * a.rect.height;
    final areaB = b.rect.width * b.rect.height;
    return areaA.compareTo(areaB);
  });

  return hits.first;
}

Color colorForCategory(InspectableCategory category) {
  switch (category) {
    case InspectableCategory.button:
      return const Color(0xFF0F6FFF);
    case InspectableCategory.input:
      return const Color(0xFF00A86B);
    case InspectableCategory.tappable:
      return const Color(0xFFE28900);
    case InspectableCategory.card:
      return const Color(0xFF7B42F6);
    case InspectableCategory.listItem:
      return const Color(0xFF00B7C2);
    case InspectableCategory.any:
      return const Color(0xFFEE3A3A);
  }
}

Color translucent(Color color, double opacity) {
  return Color.fromRGBO(color.red, color.green, color.blue, opacity);
}

Rect clampRect(Rect rect, Size size) {
  final left = max(0.0, rect.left);
  final top = max(0.0, rect.top);
  final right = min(size.width, rect.right);
  final bottom = min(size.height, rect.bottom);
  return Rect.fromLTRB(left, top, right, bottom);
}
