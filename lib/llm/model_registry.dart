import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_llm_service.dart';

class LlmModel {
  LlmModel({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.quantHint,
  });

  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final String? quantHint;

  factory LlmModel.fromMap(Map<String, dynamic> map) {
    return LlmModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Modelo',
      path: map['path'] as String? ?? '',
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      quantHint: map['quantHint'] as String?,
    );
  }
}

class ModelRegistryState {
  const ModelRegistryState({
    this.models = const [],
    this.activeModelId,
    this.activeLoaded = false,
    this.isLoading = false,
    this.downloadProgress = const {},
    this.downloadLabels = const {},
    this.downloadedBytes = const {},
    this.totalBytes = const {},
    this.lastError,
  });

  final List<LlmModel> models;
  final String? activeModelId;
  final bool activeLoaded;
  final bool isLoading;
  final Map<String, double> downloadProgress;
  final Map<String, String> downloadLabels;
  final Map<String, int> downloadedBytes;
  final Map<String, int> totalBytes;
  final String? lastError;

  ModelRegistryState copyWith({
    List<LlmModel>? models,
    String? activeModelId,
    bool? activeLoaded,
    bool? isLoading,
    Map<String, double>? downloadProgress,
    Map<String, String>? downloadLabels,
    Map<String, int>? downloadedBytes,
    Map<String, int>? totalBytes,
    String? lastError,
  }) {
    return ModelRegistryState(
      models: models ?? this.models,
      activeModelId: activeModelId ?? this.activeModelId,
      activeLoaded: activeLoaded ?? this.activeLoaded,
      isLoading: isLoading ?? this.isLoading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadLabels: downloadLabels ?? this.downloadLabels,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      lastError: lastError,
    );
  }

  LlmModel? get activeModel {
    if (activeModelId == null) {
      return null;
    }
    return models.where((model) => model.id == activeModelId).firstOrNull;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class ModelRegistry extends StateNotifier<ModelRegistryState> {
  ModelRegistry(this._service) : super(const ModelRegistryState()) {
    _sub = _service.events.listen(_onEvent);
  }

  final LocalLlmService _service;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final Map<String, double> _lastLoggedProgress = {};
  final Map<String, int> _lastLoggedBytes = {};

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final models = await _service.listModels();
    final active = await _service.getActiveModel();
    final activeId = active['id'] as String?;
    final loaded = active['loaded'] as bool? ?? false;
    state = state.copyWith(
      models: models.map(LlmModel.fromMap).toList(),
      activeModelId: activeId,
      activeLoaded: loaded,
      isLoading: false,
    );
  }

  Future<void> setActive(String modelId) async {
    await _service.setActiveModel(modelId);
    await refresh();
  }

  Future<void> importModel(String uriOrPath) async {
    await _service.importModel(uriOrPath);
    await refresh();
  }

  Future<void> downloadModel(String url, String fileName) async {
    final modelId = await _service.downloadModel(url, fileName);
    if (modelId != null) {
      final next = Map<String, double>.from(state.downloadProgress);
      next[modelId] = -1.0;
      final labels = Map<String, String>.from(state.downloadLabels);
      labels[modelId] = fileName;
      final downloaded = Map<String, int>.from(state.downloadedBytes);
      downloaded[modelId] = 0;
      final total = Map<String, int>.from(state.totalBytes);
      total[modelId] = -1;
      state = state.copyWith(
        downloadProgress: next,
        downloadLabels: labels,
        downloadedBytes: downloaded,
        totalBytes: total,
        lastError: null,
      );
    }
  }

  Future<bool> loadActiveModel(Map<String, dynamic> params) async {
    final modelId = state.activeModelId;
    if (modelId == null) {
      return false;
    }
    final loaded = await _service.loadModel(modelId, params);
    state = state.copyWith(activeLoaded: loaded);
    return loaded;
  }

  Future<void> unloadModel() async {
    await _service.unloadModel();
    state = state.copyWith(activeLoaded: false);
  }

  Future<bool> deleteModel(String modelId) async {
    final removed = await _service.deleteModel(modelId);
    if (removed) {
      await refresh();
    }
    return removed;
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'download_progress') {
      final modelId = event['modelId']?.toString();
      final progress = (event['progress01'] as num?)?.toDouble() ?? 0.0;
      final fileName = event['fileName']?.toString();
      final downloaded = (event['downloadedBytes'] as num?)?.toInt();
      final total = (event['totalBytes'] as num?)?.toInt();
      if (modelId == null) {
        return;
      }
      final next = Map<String, double>.from(state.downloadProgress);
      next[modelId] = progress;
      final labels = Map<String, String>.from(state.downloadLabels);
      if (fileName != null && fileName.isNotEmpty) {
        labels[modelId] = fileName;
      }
      final downloadedMap = Map<String, int>.from(state.downloadedBytes);
      final totalMap = Map<String, int>.from(state.totalBytes);
      if (downloaded != null) {
        downloadedMap[modelId] = downloaded;
      }
      if (total != null) {
        totalMap[modelId] = total;
      }
      if (progress >= 1.0) {
        next.remove(modelId);
        labels.remove(modelId);
        state = state.copyWith(downloadProgress: next, downloadLabels: labels);
        downloadedMap.remove(modelId);
        totalMap.remove(modelId);
        state = state.copyWith(downloadedBytes: downloadedMap, totalBytes: totalMap);
        debugPrint('Download completo: ${fileName ?? modelId}');
        if (state.activeModelId == null) {
          unawaited(setActive(modelId));
        } else {
          refresh();
        }
      } else {
        state = state.copyWith(
          downloadProgress: next,
          downloadLabels: labels,
          downloadedBytes: downloadedMap,
          totalBytes: totalMap,
        );
        _maybeLogDownload(modelId, fileName, progress, downloaded, total);
      }
    } else if (type == 'download_error') {
      final modelId = event['modelId']?.toString();
      final message = event['message']?.toString() ?? 'Falha no download';
      final fileName = event['fileName']?.toString();
      final next = Map<String, double>.from(state.downloadProgress);
      if (modelId != null) {
        next.remove(modelId);
        final labels = Map<String, String>.from(state.downloadLabels);
        if (fileName != null && fileName.isNotEmpty) {
          labels[modelId] = fileName;
        }
        labels.remove(modelId);
        final downloaded = Map<String, int>.from(state.downloadedBytes);
        final total = Map<String, int>.from(state.totalBytes);
        downloaded.remove(modelId);
        total.remove(modelId);
        state = state.copyWith(
          downloadProgress: next,
          downloadLabels: labels,
          downloadedBytes: downloaded,
          totalBytes: total,
          lastError: message,
        );
        debugPrint('Download falhou: ${fileName ?? modelId} -> $message');
      } else {
        state = state.copyWith(lastError: message);
        debugPrint('Download falhou: $message');
      }
    } else if (type == 'model_error') {
      final message = event['message']?.toString() ?? 'Falha ao carregar modelo';
      state = state.copyWith(lastError: message);
    } else if (type == 'model_loaded') {
      final modelId = event['modelId']?.toString();
      if (modelId != null && modelId == state.activeModelId) {
        state = state.copyWith(activeLoaded: true);
      }
    }
  }

  void _maybeLogDownload(
    String modelId,
    String? fileName,
    double progress,
    int? downloaded,
    int? total,
  ) {
    final lastProgress = _lastLoggedProgress[modelId];
    final lastBytes = _lastLoggedBytes[modelId];
    final progressChanged = progress >= 0 &&
        (lastProgress == null || (progress - lastProgress).abs() >= 0.01);
    final bytesChanged = progress < 0 &&
        downloaded != null &&
        (lastBytes == null || (downloaded - lastBytes).abs() >= 1024 * 1024);
    if (!progressChanged && !bytesChanged) {
      return;
    }
    _lastLoggedProgress[modelId] = progress;
    if (downloaded != null) {
      _lastLoggedBytes[modelId] = downloaded;
    }
    final name = fileName ?? modelId;
    final percent = progress >= 0 ? '${(progress * 100).toStringAsFixed(0)}%' : '...';
    final bytesInfo = (downloaded != null && (total ?? -1) > 0)
        ? '${_formatBytes(downloaded)} / ${_formatBytes(total!)}'
        : (downloaded != null && downloaded > 0
            ? _formatBytes(downloaded)
            : '');
    debugPrint('Download $name: $percent${bytesInfo.isNotEmpty ? ' ($bytesInfo)' : ''}');
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size > 1024 && unit < units.length - 1) {
      size /= 1024;
      unit += 1;
    }
    return '${size.toStringAsFixed(1)} ${units[unit]}';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final localLlmServiceProvider = Provider<LocalLlmService>((ref) {
  return LocalLlmService();
});

final modelRegistryProvider =
    StateNotifierProvider<ModelRegistry, ModelRegistryState>((ref) {
  return ModelRegistry(ref.read(localLlmServiceProvider));
});
