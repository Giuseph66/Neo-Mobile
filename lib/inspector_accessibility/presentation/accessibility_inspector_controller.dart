import 'dart:async';
import 'package:flutter/material.dart';
import '../data/inspector_repository.dart';
import '../data/inspector_repository_impl.dart';
import '../domain/models/ui_node.dart';
import '../domain/models/ui_snapshot.dart';

class AccessibilityInspectorController extends ChangeNotifier {
  final InspectorRepository _repository = InspectorRepositoryImpl();

  bool _enabled = false;
  bool _overlayVisible = false;
  bool _textVisible = false;
  UiNode? _selectedNode;
  bool _aimMode = false;
  Offset? _aimPosition;
  UiSnapshot? _lastSnapshot;
  StreamSubscription<UiSnapshot>? _nodesSubscription;

  bool get enabled => _enabled;
  bool get overlayVisible => _overlayVisible;
  bool get textVisible => _textVisible;
  UiNode? get selectedNode => _selectedNode;
  bool get aimMode => _aimMode;
  Offset? get aimPosition => _aimPosition;
  UiSnapshot? get lastSnapshot => _lastSnapshot;

  Stream<UiSnapshot> get nodesStream => _repository.nodesStream;

  AccessibilityInspectorController() {
    _listenToNodesStream();
  }

  void _listenToNodesStream() {
    _nodesSubscription?.cancel();
    _nodesSubscription = nodesStream.listen((snapshot) {
      _lastSnapshot = snapshot;
      notifyListeners();
    });
  }

  Future<bool> checkAccessibilityEnabled() async {
    return await _repository.isAccessibilityEnabled();
  }

  Future<void> start() async {
    if (_enabled) return;

    // Verificar se o Accessibility Service está habilitado antes de tentar iniciar
    final isEnabled = await _repository.isAccessibilityEnabled();
    if (!isEnabled) {
      throw Exception('Accessibility Service não está habilitado. Por favor, habilite nas configurações.');
    }

    try {
      await _repository.setInspectorEnabled(true);
      _enabled = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_enabled) return;

    await _repository.setInspectorEnabled(false);
    await _repository.setOverlayVisible(false);
    _enabled = false;
    _overlayVisible = false;
    _selectedNode = null;
    _aimMode = false;
    _aimPosition = null;
    notifyListeners();
  }

  Future<void> setOverlayVisible(bool visible) async {
    if (_overlayVisible == visible) return;

    await _repository.setOverlayVisible(visible);
    _overlayVisible = visible;
    notifyListeners();
  }

  Future<void> setTextVisible(bool visible) async {
    if (_textVisible == visible) return;

    await _repository.setTextVisible(visible);
    _textVisible = visible;
    notifyListeners();
  }

  Future<void> setAimPosition(Offset? position) async {
    _aimPosition = position;
    if (position != null) {
      await _repository.setAimPosition(
        position.dx.toInt(),
        position.dy.toInt(),
      );
    }
    notifyListeners();
  }

  void setAimMode(bool enabled) {
    _aimMode = enabled;
    if (!enabled) {
      _aimPosition = null;
    }
    notifyListeners();
  }

  Future<void> selectNode(UiNode? node) async {
    _selectedNode = node;
    if (node != null) {
      await _repository.selectNode(node.id);
    }
    notifyListeners();
  }

  Future<bool> clickSelected() async {
    if (_selectedNode == null) return false;
    return await _repository.clickSelected();
  }

  Future<bool> scrollForward() async {
    if (_selectedNode == null) return false;
    return await _repository.scrollForward();
  }

  Future<bool> scrollBackward() async {
    if (_selectedNode == null) return false;
    return await _repository.scrollBackward();
  }

  Future<void> tap(int x, int y, {int durationMs = 100}) async {
    await _repository.tap(x, y, durationMs: durationMs);
  }

  Future<void> swipe(int x1, int y1, int x2, int y2, {int durationMs = 300}) async {
    await _repository.swipe(x1, y1, x2, y2, durationMs: durationMs);
  }

  @override
  void dispose() {
    _nodesSubscription?.cancel();
    super.dispose();
  }
}

