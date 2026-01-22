import 'package:flutter/material.dart';
import 'node_selector.dart';

class UiNode {
  final String id;
  final NodeSelector selector;
  final Rect bounds;
  final String className;
  final String packageName;
  final String? viewIdResourceName;
  final bool clickable;
  final bool enabled;
  final bool scrollable;
  final bool isTextField;
  final String? text;

  UiNode({
    required this.id,
    required this.selector,
    required this.bounds,
    required this.className,
    required this.packageName,
    this.viewIdResourceName,
    required this.clickable,
    required this.enabled,
    required this.scrollable,
    required this.isTextField,
    this.text,
  });

  factory UiNode.fromJson(Map<String, dynamic> json) {
    final boundsJson = json['bounds'] as Map<String, dynamic>;
    return UiNode(
      id: json['id'] as String,
      selector: NodeSelector.fromJson(json['selector'] as Map<String, dynamic>),
      bounds: Rect.fromLTRB(
        (boundsJson['left'] as num).toDouble(),
        (boundsJson['top'] as num).toDouble(),
        (boundsJson['right'] as num).toDouble(),
        (boundsJson['bottom'] as num).toDouble(),
      ),
      className: json['className'] as String,
      packageName: json['packageName'] as String,
      viewIdResourceName: json['viewIdResourceName'] as String?,
      clickable: json['clickable'] as bool,
      enabled: json['enabled'] as bool,
      scrollable: json['scrollable'] as bool,
      isTextField: json['isTextField'] as bool,
      text: json['text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'selector': selector.toJson(),
      'bounds': {
        'left': bounds.left,
        'top': bounds.top,
        'right': bounds.right,
        'bottom': bounds.bottom,
      },
      'className': className,
      'packageName': packageName,
      if (viewIdResourceName != null) 'viewIdResourceName': viewIdResourceName,
      'clickable': clickable,
      'enabled': enabled,
      'scrollable': scrollable,
      'isTextField': isTextField,
      if (text != null) 'text': text,
    };
  }
}

