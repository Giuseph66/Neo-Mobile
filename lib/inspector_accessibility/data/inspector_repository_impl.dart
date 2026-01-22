import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'inspector_repository.dart';
import '../domain/models/ui_snapshot.dart';

class InspectorRepositoryImpl implements InspectorRepository {
  static const MethodChannel _methodChannel = MethodChannel('inspector/actions');
  static const EventChannel _eventChannel = EventChannel('inspector/nodesStream');

  @override
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod<void>('openAccessibilitySettings');
    } catch (e) {
      // Ignorar erros
    }
  }

  @override
  Future<void> setInspectorEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'setInspectorEnabled',
        {'enabled': enabled},
      );
    } catch (e) {
      if (e is PlatformException && e.code == 'NOT_ENABLED') {
        rethrow;
      }
    }
  }

  @override
  Future<void> setOverlayVisible(bool visible) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'setOverlayVisible',
        {'visible': visible},
      );
    } catch (e) {
      // Ignorar erros
    }
  }

  @override
  Future<void> setTextVisible(bool visible) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'setTextVisible',
        {'visible': visible},
      );
    } catch (e) {
      // Ignorar erros
    }
  }

  @override
  Future<void> setAimPosition(int x, int y) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'setAimPosition',
        {'x': x, 'y': y},
      );
    } catch (e) {
      // Ignorar erros
    }
  }

  @override
  Future<void> selectNode(String nodeId) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'selectNode',
        {'nodeId': nodeId},
      );
    } catch (e) {
      // Ignorar erros
    }
  }

  @override
  Future<bool> clickSelected() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('clickSelected');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> scrollForward() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('scrollForward');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> scrollBackward() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('scrollBackward');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> tap(int x, int y, {int durationMs = 100}) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'tap',
        {
          'x': x,
          'y': y,
          'durationMs': durationMs,
        },
      );
    } catch (e) {
      // Ignorar erros
    }
  }

  @override
  Future<void> swipe(int x1, int y1, int x2, int y2, {int durationMs = 300}) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'swipe',
        {
          'x1': x1,
          'y1': y1,
          'x2': x2,
          'y2': y2,
          'durationMs': durationMs,
        },
      );
    } catch (e) {
      // Ignorar erros
    }
  }

  @override
  Stream<UiSnapshot> get nodesStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event == null) {
            return UiSnapshot(nodes: [], timestamp: DateTime.now().millisecondsSinceEpoch);
          }
          try {
            final jsonString = event.toString();
            final json = jsonDecode(jsonString) as Map<String, dynamic>;
            return UiSnapshot.fromJson(json);
          } catch (e) {
            return UiSnapshot(nodes: [], timestamp: DateTime.now().millisecondsSinceEpoch);
          }
        });
  }
}

