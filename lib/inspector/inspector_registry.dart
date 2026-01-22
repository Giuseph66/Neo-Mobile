import 'package:flutter/material.dart';

import 'inspector_node.dart';

class InspectableEntry {
  InspectableEntry({
    required this.id,
    required this.key,
    required this.widgetType,
    required this.category,
    this.label,
    this.widgetKey,
    this.parentWidgetType,
  });

  final String id;
  final GlobalKey key;
  final String widgetType;
  final InspectableCategory category;
  final String? label;
  final String? widgetKey;
  final String? parentWidgetType;
}

class InspectorRegistry {
  InspectorRegistry._();

  static final InspectorRegistry instance = InspectorRegistry._();

  final Map<String, InspectableEntry> _entries = {};

  void register(InspectableEntry entry) {
    _entries[entry.id] = entry;
  }

  void unregister(String id) {
    _entries.remove(id);
  }

  List<InspectableEntry> get entries => _entries.values.toList(growable: false);
}
