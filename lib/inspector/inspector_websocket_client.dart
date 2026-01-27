import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class InspectorWebSocketClient {
  InspectorWebSocketClient({this.onStatusChanged, this.onMessage});

  VoidCallback? onStatusChanged;
  ValueChanged<Map<String, dynamic>>? onMessage;

  WebSocket? _socket;
  String? _url;
  bool _connecting = false;

  bool get connected => _socket != null;
  bool get connecting => _connecting;
  String? get url => _url;

  Future<void> ensureConnected(String url) async {
    if (_connecting) {
      return;
    }
    if (_socket != null && _url == url) {
      return;
    }
    _connecting = true;
    await disconnect();
    try {
      final socket = await WebSocket.connect(url);
      socket.pingInterval = const Duration(seconds: 5);
      _url = url;
      _socket = socket;
      onStatusChanged?.call();
      socket.listen(
        (data) {
          if (onMessage == null) {
            return;
          }
          final decoded = _decodeMessage(data);
          if (decoded != null) {
            onMessage?.call(decoded);
          }
        },
        onDone: () {
          _socket = null;
          onStatusChanged?.call();
        },
        onError: (_) {
          _socket = null;
          onStatusChanged?.call();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _socket = null;
      onStatusChanged?.call();
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
      onStatusChanged?.call();
    }
  }

  void sendJson(Object message) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    socket.add(jsonEncode(message));
  }

  Map<String, dynamic>? _decodeMessage(Object data) {
    try {
      final payload = data is String ? data : utf8.decode(data as List<int>);
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
