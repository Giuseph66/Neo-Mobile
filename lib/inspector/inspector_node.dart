import 'package:flutter/material.dart';

enum InspectableCategory {
  any,
  button,
  input,
  tappable,
  card,
  listItem,
}

class InspectorNode {
  const InspectorNode({
    required this.id,
    required this.rect,
    required this.widgetType,
    required this.category,
    this.label,
    this.widgetKey,
    this.parentWidgetType,
  });

  final String id;
  final Rect rect;
  final String widgetType;
  final InspectableCategory category;
  final String? label;
  final String? widgetKey;
  final String? parentWidgetType;

  String get title => label ?? widgetType;

  String debugInfo() {
    return [
      'widgetType: $widgetType',
      if (label != null) 'label: $label',
      if (widgetKey != null) 'key: $widgetKey',
      if (parentWidgetType != null) 'parent: $parentWidgetType',
      'rect: ${rect.left.toStringAsFixed(1)},'
          '${rect.top.toStringAsFixed(1)},'
          '${rect.width.toStringAsFixed(1)},'
          '${rect.height.toStringAsFixed(1)}',
      'category: ${category.name}',
    ].join('\n');
  }
}
