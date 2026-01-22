import 'package:flutter/material.dart';

import 'inspector_node.dart';
import 'inspector_registry.dart';

class Inspectable extends StatefulWidget {
  const Inspectable({
    super.key,
    required this.child,
    this.label,
    this.category = InspectableCategory.any,
  });

  final Widget child;
  final String? label;
  final InspectableCategory category;

  @override
  State<Inspectable> createState() => _InspectableState();
}

class _InspectableState extends State<Inspectable> {
  final GlobalKey _key = GlobalKey();
  late final String _id = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  @override
  void didUpdateWidget(covariant Inspectable oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  @override
  void dispose() {
    InspectorRegistry.instance.unregister(_id);
    super.dispose();
  }

  void _register() {
    final context = _key.currentContext;
    if (context == null) {
      return;
    }

    InspectorRegistry.instance.register(
      InspectableEntry(
        id: _id,
        key: _key,
        widgetType: widget.child.runtimeType.toString(),
        category: widget.category,
        label: widget.label,
        widgetKey: widget.child.key?.toString(),
        parentWidgetType: _findParentType(context),
      ),
    );
  }

  String? _findParentType(BuildContext context) {
    String? parentType;
    context.visitAncestorElements((element) {
      parentType = element.widget.runtimeType.toString();
      return false;
    });
    return parentType;
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
