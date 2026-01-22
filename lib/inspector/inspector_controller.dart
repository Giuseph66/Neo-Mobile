import 'package:flutter/material.dart';

import 'inspector_node.dart';
import 'inspector_registry.dart';

enum InspectorMode { highlight, list }

enum InspectorFilter { all, buttons, inputs, tappable }

class InspectorController extends ChangeNotifier with WidgetsBindingObserver {
  bool _enabled = false;
  bool _showRects = true;
  InspectorMode _mode = InspectorMode.highlight;
  InspectorFilter _filter = InspectorFilter.all;
  InspectorNode? _selectedNode;
  List<InspectorNode> _nodes = const [];
  List<InspectorNode> _allNodes = const [];

  bool get enabled => _enabled;
  bool get showRects => _showRects;
  InspectorMode get mode => _mode;
  InspectorFilter get filter => _filter;
  InspectorNode? get selectedNode => _selectedNode;
  List<InspectorNode> get nodes => _nodes;

  void setEnabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (value) {
      WidgetsBinding.instance.addObserver(this);
      _scheduleRefresh();
    } else {
      WidgetsBinding.instance.removeObserver(this);
      _selectedNode = null;
      _nodes = const [];
      _allNodes = const [];
    }
    notifyListeners();
  }

  void setMode(InspectorMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  void setFilter(InspectorFilter filter) {
    if (_filter == filter) {
      return;
    }
    _filter = filter;
    _applyFilter();
    notifyListeners();
  }

  void toggleRects() {
    _showRects = !_showRects;
    notifyListeners();
  }

  void selectNode(InspectorNode? node) {
    _selectedNode = node;
    notifyListeners();
  }

  void _scheduleRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_enabled) {
        refreshNodes();
      }
    });
  }

  void refreshNodes() {
    if (!_enabled) {
      return;
    }

    final entries = InspectorRegistry.instance.entries;
    final nodes = <InspectorNode>[];

    for (final entry in entries) {
      final context = entry.key.currentContext;
      if (context == null) {
        continue;
      }
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) {
        continue;
      }
      if (!renderObject.hasSize || !renderObject.attached) {
        continue;
      }

      final offset = renderObject.localToGlobal(Offset.zero);
      final rect = offset & renderObject.size;

      nodes.add(
        InspectorNode(
          id: entry.id,
          rect: rect,
          widgetType: entry.widgetType,
          category: entry.category,
          label: entry.label,
          widgetKey: entry.widgetKey,
          parentWidgetType: entry.parentWidgetType,
        ),
      );
    }

    _allNodes = nodes;
    _nodes = _filterNodes(_allNodes);
    _syncSelected(_allNodes);
    notifyListeners();
  }

  void _applyFilter() {
    _nodes = _filterNodes(_allNodes);
    if (_selectedNode != null && !_nodes.any((node) => node.id == _selectedNode!.id)) {
      _selectedNode = null;
    }
  }

  List<InspectorNode> _filterNodes(List<InspectorNode> nodes) {
    return nodes.where((node) => _passesFilter(node.category)).toList(growable: false);
  }

  bool _passesFilter(InspectableCategory category) {
    switch (_filter) {
      case InspectorFilter.all:
        return true;
      case InspectorFilter.buttons:
        return category == InspectableCategory.button;
      case InspectorFilter.inputs:
        return category == InspectableCategory.input;
      case InspectorFilter.tappable:
        return category == InspectableCategory.tappable;
    }
  }

  void _syncSelected(List<InspectorNode> latestNodes) {
    if (_selectedNode == null) {
      return;
    }
    final updated = latestNodes.where((node) => node.id == _selectedNode!.id).toList();
    if (updated.isEmpty) {
      _selectedNode = null;
    } else {
      _selectedNode = updated.first;
    }
  }

  @override
  void didChangeMetrics() {
    _scheduleRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
