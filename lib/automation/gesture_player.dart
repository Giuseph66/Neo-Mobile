import 'dart:async';
import 'dart:math';

import 'dart:ui';

import 'package:flutter/gestures.dart';

import 'gesture_models.dart';

class GesturePlayer {
  bool _busy = false;

  bool get isBusy => _busy;

  Future<void> playActions(List<GestureAction> actions) async {
    if (_busy || actions.isEmpty) {
      return;
    }
    _busy = true;
    try {
      for (final action in actions) {
        await _play(action);
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _play(GestureAction action) async {
    switch (action.kind) {
      case GestureKind.tap:
        await _tap(action.position);
        break;
      case GestureKind.longPress:
        await _longPress(action.position, action.holdDurationMs);
        break;
      case GestureKind.drag:
        final end = action.end ?? action.position;
        await _drag(action.position, end, action.dragDurationMs);
        break;
    }
  }

  Future<void> _tap(Offset position) async {
    final pointer = _nextPointer();
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        position: position,
        pointer: pointer,
        kind: PointerDeviceKind.touch,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        position: position,
        pointer: pointer,
        kind: PointerDeviceKind.touch,
      ),
    );
  }

  Future<void> _longPress(Offset position, int holdMs) async {
    final pointer = _nextPointer();
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        position: position,
        pointer: pointer,
        kind: PointerDeviceKind.touch,
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: holdMs));
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        position: position,
        pointer: pointer,
        kind: PointerDeviceKind.touch,
      ),
    );
  }

  Future<void> _drag(Offset start, Offset end, int dragMs) async {
    final pointer = _nextPointer();
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        position: start,
        pointer: pointer,
        kind: PointerDeviceKind.touch,
      ),
    );

    final steps = max(6, dragMs ~/ 32);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final position = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      GestureBinding.instance.handlePointerEvent(
        PointerMoveEvent(
          position: position,
          pointer: pointer,
          kind: PointerDeviceKind.touch,
        ),
      );
      await Future<void>.delayed(Duration(milliseconds: dragMs ~/ steps));
    }

    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        position: end,
        pointer: pointer,
        kind: PointerDeviceKind.touch,
      ),
    );
  }

  int _nextPointer() {
    _pointerCounter++;
    return _pointerCounter;
  }
}

int _pointerCounter = 0;
