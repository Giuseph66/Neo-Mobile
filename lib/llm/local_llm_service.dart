import 'dart:async';

import 'package:flutter/services.dart';

class LocalLlmService {
  static const MethodChannel _channel = MethodChannel('local_llm');
  static const EventChannel _eventChannel = EventChannel('local_llm_events');

  Stream<Map<String, dynamic>> get events {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event as Map);
      }
      return <String, dynamic>{};
    });
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final result = await _channel.invokeMethod<dynamic>('getDeviceInfo');
    if (result is Map) {
      return Map<String, dynamic>.from(result as Map);
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listModels() async {
    final result = await _channel.invokeMethod<dynamic>('listModels');
    if (result is List) {
      return result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getActiveModel() async {
    final result = await _channel.invokeMethod<dynamic>('getActiveModel');
    if (result is Map) {
      return Map<String, dynamic>.from(result as Map);
    }
    return <String, dynamic>{};
  }

  Future<bool> setActiveModel(String modelId) async {
    final result = await _channel.invokeMethod<bool>(
      'setActiveModel',
      {'modelId': modelId},
    );
    return result ?? false;
  }

  Future<String?> importModel(String uriOrPath) async {
    final result = await _channel.invokeMethod<String>(
      'importModel',
      {'fileUri': uriOrPath},
    );
    return result;
  }

  Future<String?> downloadModel(String url, String fileName) async {
    final result = await _channel.invokeMethod<String>(
      'downloadModel',
      {'url': url, 'fileName': fileName},
    );
    return result;
  }

  Future<bool> loadModel(String modelId, Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<bool>(
      'loadModel',
      {'modelId': modelId, 'params': params},
    );
    return result ?? false;
  }

  Future<bool> unloadModel() async {
    final result = await _channel.invokeMethod<bool>('unloadModel');
    return result ?? false;
  }

  Future<bool> deleteModel(String modelId) async {
    final result = await _channel.invokeMethod<bool>(
      'deleteModel',
      {'modelId': modelId},
    );
    return result ?? false;
  }

  Future<String?> generate(String prompt, Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>(
      'generate',
      {'prompt': prompt, 'params': params},
    );
    return result;
  }

  Future<bool> stopGeneration(String requestId) async {
    final result = await _channel.invokeMethod<bool>(
      'stopGeneration',
      {'requestId': requestId},
    );
    return result ?? false;
  }

  Future<Map<String, dynamic>> getProcessStats() async {
    final result = await _channel.invokeMethod<dynamic>('getProcessStats');
    if (result is Map) {
      return Map<String, dynamic>.from(result as Map);
    }
    return <String, dynamic>{};
  }
}
