import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inspector/inspector_websocket_client.dart';
import '../data/inspector_repository.dart';
import '../data/inspector_repository_impl.dart';
import '../domain/models/ui_node.dart';
import '../domain/models/ui_snapshot.dart';
import '../../../chat_control/services/element_storage_service.dart';

final accessibilityInspectorControllerProvider = ChangeNotifierProvider<AccessibilityInspectorController>((ref) {
  return AccessibilityInspectorController();
});

class AccessibilityInspectorController extends ChangeNotifier {
  final InspectorRepository _repository = InspectorRepositoryImpl();
  final ElementStorageService _storageService = ElementStorageService();
  final InspectorWebSocketClient _webSocketClient = InspectorWebSocketClient();

  bool _enabled = false;
  bool _overlayVisible = false;
  bool _textVisible = false;
  UiNode? _selectedNode;
  bool _aimMode = false;
  Offset? _aimPosition;
  UiSnapshot? _lastSnapshot;
  StreamSubscription<UiSnapshot>? _nodesSubscription;
  bool _streamingEnabled = false;
  String _streamUrl = 'ws://192.168.0.25:7071';

  bool get enabled => _enabled;
  bool get overlayVisible => _overlayVisible;
  bool get textVisible => _textVisible;
  UiNode? get selectedNode => _selectedNode;
  bool get aimMode => _aimMode;
  Offset? get aimPosition => _aimPosition;
  UiSnapshot? get lastSnapshot => _lastSnapshot;
  bool get streamingEnabled => _streamingEnabled;
  bool get streamingConnected => _webSocketClient.connected;
  bool get streamingConnecting => _webSocketClient.connecting;
  String get streamUrl => _streamUrl;

  Stream<UiSnapshot> get nodesStream => _repository.nodesStream;

  AccessibilityInspectorController() {
    _webSocketClient.onStatusChanged = notifyListeners;
    _webSocketClient.onMessage = _handleIncomingMessage;
    _listenToNodesStream();
  }

  void _listenToNodesStream() {
    _nodesSubscription?.cancel();
    _nodesSubscription = nodesStream.listen((snapshot) {
      _lastSnapshot = snapshot;
      
      // Salvar elementos no banco quando o Inspector estiver ativo
      if (_enabled && snapshot.nodes.isNotEmpty) {
        _storageService.saveSnapshot(snapshot).catchError((e) {
          // Ignorar erros de salvamento silenciosamente
        });
      }

      _sendSnapshot(snapshot);
      
      notifyListeners();
    });
  }

  Future<bool> checkAccessibilityEnabled() async {
    return await _repository.isAccessibilityEnabled();
  }

  Future<List<Map<String, String>>> getInstalledApps() async {
    return await _repository.getInstalledApps();
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
      if (_streamingEnabled) {
        unawaited(_webSocketClient.ensureConnected(_streamUrl));
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_enabled) return;

    await _repository.setInspectorEnabled(false);
    await _repository.setOverlayVisible(false);
    _storageService.resetCurrentGroup(); // Resetar grupo ao parar
    _enabled = false;
    _overlayVisible = false;
    _selectedNode = null;
    _aimMode = false;
    _aimPosition = null;
    _webSocketClient.onStatusChanged = null;
    _webSocketClient.onMessage = null;
    unawaited(_webSocketClient.disconnect());
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

  void setStreamingEnabled(bool value) {
    if (_streamingEnabled == value) return;
    _streamingEnabled = value;
    if (_streamingEnabled && _enabled) {
      unawaited(_webSocketClient.ensureConnected(_streamUrl));
    } else {
      unawaited(_webSocketClient.disconnect());
    }
    notifyListeners();
  }

  void setStreamUrl(String url) {
    if (url.isEmpty || url == _streamUrl) return;
    _streamUrl = url;
    if (_streamingEnabled && _enabled) {
      unawaited(_webSocketClient.ensureConnected(_streamUrl));
    }
    notifyListeners();
  }

  void _sendSnapshot(UiSnapshot snapshot) {
    if (!_streamingEnabled || !_enabled) {
      return;
    }
    if (!_webSocketClient.connected) {
      if (!_webSocketClient.connecting) {
        unawaited(_webSocketClient.ensureConnected(_streamUrl));
      }
      return;
    }

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logicalSize = view.physicalSize / view.devicePixelRatio;

    final payload = <String, dynamic>{
      'type': 'snapshot',
      'timestamp': DateTime.now().toIso8601String(),
      'screen': {
        'width': logicalSize.width,
        'height': logicalSize.height,
        'pixelRatio': view.devicePixelRatio,
      },
      'selectedId': _selectedNode?.id,
      'nodes': snapshot.nodes
          .map((node) {
            final rect = node.bounds;
            final category = node.isTextField
                ? 'input'
                : node.clickable
                    ? 'tappable'
                    : 'any';
            final label = node.text ?? node.viewIdResourceName ?? node.className;
            return {
              'id': node.id,
              'rect': {
                'left': rect.left,
                'top': rect.top,
                'width': rect.width,
                'height': rect.height,
              },
              'widgetType': node.className,
              'category': category,
              'label': label,
              'packageName': node.packageName,
              'viewIdResourceName': node.viewIdResourceName,
              'clickable': node.clickable,
              'enabled': node.enabled,
              'scrollable': node.scrollable,
              'isTextField': node.isTextField,
            };
          })
          .toList(growable: false),
    };

    _webSocketClient.sendJson(payload);
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    if (!_enabled) {
      return;
    }
    if (message['type'] != 'command') {
      return;
    }

    final action = message['action'];
    if (action == 'tap') {
      final x = (message['x'] as num?)?.toInt();
      final y = (message['y'] as num?)?.toInt();
      final durationMs = (message['durationMs'] as num?)?.toInt() ?? 100;
      if (x != null && y != null) {
        unawaited(tap(x, y, durationMs: durationMs));
      }
      return;
    }

    if (action == 'swipe') {
      final x1 = (message['x1'] as num?)?.toInt();
      final y1 = (message['y1'] as num?)?.toInt();
      final x2 = (message['x2'] as num?)?.toInt();
      final y2 = (message['y2'] as num?)?.toInt();
      final durationMs = (message['durationMs'] as num?)?.toInt() ?? 300;
      if (x1 != null && y1 != null && x2 != null && y2 != null) {
        unawaited(swipe(x1, y1, x2, y2, durationMs: durationMs));
      }
      return;
    }

    if (action == 'selectNode') {
      final nodeId = message['nodeId'] as String?;
      if (nodeId != null && nodeId.isNotEmpty) {
        _selectedNode = _lastSnapshot?.findNodeById(nodeId);
        unawaited(_repository.selectNode(nodeId));
        notifyListeners();
      }
      return;
    }

    if (action == 'navigateHome') {
      unawaited(_repository.navigateHome());
      return;
    }

    if (action == 'navigateBack') {
      unawaited(_repository.navigateBack());
      return;
    }

    if (action == 'navigateRecents') {
      unawaited(_repository.navigateRecents());
      return;
    }

    if (action == 'inputText') {
      final text = message['text'] as String? ?? '';
      unawaited(inputText(text));
    }
  }

  Future<bool> inputText(String text) async {
    return await _repository.inputText(text);
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

  Future<void> navigateHome() async {
    await _repository.navigateHome();
  }

  Future<void> navigateBack() async {
    await _repository.navigateBack();
  }

  Future<void> navigateRecents() async {
    await _repository.navigateRecents();
  }

  Future<void> sendLog(String message, {String level = 'info'}) async {
    final payload = {
      'type': 'log',
      'timestamp': DateTime.now().toIso8601String(),
      'message': message,
      'level': level,
    };
    _webSocketClient.sendJson(payload);
    // Também opcionalmente enviar para Kotlin se quisermos logs do sistema lá
    await _repository.sendLog(message, level: level);
  }

  Future<void> sendExecutionStatus(String status, {String routineName = '', int currentStep = -1}) async {
    final payload = {
      'type': 'execution_status',
      'status': status,
      'routineName': routineName,
      'currentStep': currentStep,
    };
    _webSocketClient.sendJson(payload);
    await _repository.sendExecutionStatus(status, routineName: routineName, currentStep: currentStep);
  }

  @override
  void dispose() {
    _nodesSubscription?.cancel();
    _webSocketClient.onStatusChanged = null;
    _webSocketClient.onMessage = null;
    unawaited(_webSocketClient.disconnect());
    super.dispose();
  }
}
