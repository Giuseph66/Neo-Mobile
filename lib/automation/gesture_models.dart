import 'dart:convert';

import 'package:flutter/material.dart';

enum GestureKind { tap, longPress, drag }

class GestureAction {
  GestureAction.tap({required this.position})
      : kind = GestureKind.tap,
        end = null,
        holdDurationMs = 80,
        dragDurationMs = 0;

  GestureAction.longPress({required this.position, required this.holdDurationMs})
      : kind = GestureKind.longPress,
        end = null,
        dragDurationMs = 0;

  GestureAction.drag({
    required this.position,
    required this.end,
    required this.dragDurationMs,
  })  : kind = GestureKind.drag,
        holdDurationMs = 0;

  final GestureKind kind;
  final Offset position;
  final Offset? end;
  int holdDurationMs;
  int dragDurationMs;

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.name,
      'x': position.dx,
      'y': position.dy,
      'endX': end?.dx,
      'endY': end?.dy,
      'holdMs': holdDurationMs,
      'dragMs': dragDurationMs,
    };
  }

  static GestureAction fromJson(Map<String, dynamic> json) {
    final kind = GestureKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => GestureKind.tap,
    );
    final position = Offset(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
    );
    switch (kind) {
      case GestureKind.longPress:
        return GestureAction.longPress(
          position: position,
          holdDurationMs: (json['holdMs'] as num?)?.toInt() ?? 600,
        );
      case GestureKind.drag:
        return GestureAction.drag(
          position: position,
          end: Offset(
            (json['endX'] as num?)?.toDouble() ?? 0,
            (json['endY'] as num?)?.toDouble() ?? 0,
          ),
          dragDurationMs: (json['dragMs'] as num?)?.toInt() ?? 400,
        );
      case GestureKind.tap:
      default:
        return GestureAction.tap(position: position);
    }
  }

  static String encodeList(List<GestureAction> actions) {
    return jsonEncode(actions.map((action) => action.toJson()).toList());
  }

  static List<GestureAction> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => GestureAction.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class ShortcutWorkflow {
  ShortcutWorkflow({
    required this.id,
    required this.name,
    required this.keyCombo,
    required this.actions,
  });

  final String id;
  String name;
  String keyCombo;
  List<GestureAction> actions;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'keyCombo': keyCombo,
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }

  static ShortcutWorkflow fromJson(Map<String, dynamic> json) {
    return ShortcutWorkflow(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Workflow',
      keyCombo: json['keyCombo'] as String? ?? 'ctrl+alt+1',
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((item) => GestureAction.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
