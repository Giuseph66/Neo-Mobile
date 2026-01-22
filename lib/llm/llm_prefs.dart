import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_llm_service.dart';
import 'model_registry.dart';

enum PerformanceProfile { fast, standard, quality, a54, custom }

class LlmPrefsState {
  const LlmPrefsState({
    required this.profile,
    required this.ctxLen,
    required this.threads,
    required this.temp,
    required this.topP,
    required this.topK,
    required this.maxTokens,
  });

  final PerformanceProfile profile;
  final int ctxLen;
  final int threads;
  final double temp;
  final double topP;
  final int topK;
  final int maxTokens;

  LlmPrefsState copyWith({
    PerformanceProfile? profile,
    int? ctxLen,
    int? threads,
    double? temp,
    double? topP,
    int? topK,
    int? maxTokens,
  }) {
    return LlmPrefsState(
      profile: profile ?? this.profile,
      ctxLen: ctxLen ?? this.ctxLen,
      threads: threads ?? this.threads,
      temp: temp ?? this.temp,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  Map<String, dynamic> toGenerationParams() {
    return {
      'ctxLen': ctxLen,
      'threads': threads,
      'temp': temp,
      'topP': topP,
      'topK': topK,
      'maxTokens': maxTokens,
    };
  }
}

class LlmPrefsController extends StateNotifier<LlmPrefsState> {
  LlmPrefsController(this._service)
      : super(
          const LlmPrefsState(
            profile: PerformanceProfile.standard,
            ctxLen: 2048,
            threads: 4,
            temp: 0.7,
            topP: 0.9,
            topK: 40,
            maxTokens: 512,
          ),
        );

  final LocalLlmService _service;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await _service.getDeviceInfo();
    final cores = (info['cores'] as int?) ?? 4;
    final profileName = prefs.getString('llm_profile');
    final profile = profileName == null
        ? _autoProfile(info) ?? PerformanceProfile.standard
        : PerformanceProfile.values.firstWhere(
            (value) => value.name == profileName,
            orElse: () => PerformanceProfile.standard,
          );
    final defaults = _defaultsFor(profile, cores);
    state = state.copyWith(
      profile: profile,
      ctxLen: prefs.getInt('llm_ctx') ?? defaults.ctxLen,
      threads: prefs.getInt('llm_threads') ?? defaults.threads,
      temp: prefs.getDouble('llm_temp') ?? defaults.temp,
      topP: prefs.getDouble('llm_top_p') ?? defaults.topP,
      topK: prefs.getInt('llm_top_k') ?? defaults.topK,
      maxTokens: prefs.getInt('llm_max_tokens') ?? defaults.maxTokens,
    );
  }

  Future<void> setProfile(PerformanceProfile profile) async {
    final info = await _service.getDeviceInfo();
    final cores = (info['cores'] as int?) ?? 4;
    final defaults = _defaultsFor(profile, cores);
    state = defaults.copyWith(profile: profile);
    await _persist();
  }

  void updateParams({
    int? ctxLen,
    int? threads,
    double? temp,
    double? topP,
    int? topK,
    int? maxTokens,
  }) {
    state = state.copyWith(
      profile: PerformanceProfile.custom,
      ctxLen: ctxLen,
      threads: threads,
      temp: temp,
      topP: topP,
      topK: topK,
      maxTokens: maxTokens,
    );
    _persist();
  }

  Future<void> save() async {
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_profile', state.profile.name);
    await prefs.setInt('llm_ctx', state.ctxLen);
    await prefs.setInt('llm_threads', state.threads);
    await prefs.setDouble('llm_temp', state.temp);
    await prefs.setDouble('llm_top_p', state.topP);
    await prefs.setInt('llm_top_k', state.topK);
    await prefs.setInt('llm_max_tokens', state.maxTokens);
  }

  LlmPrefsState _defaultsFor(PerformanceProfile profile, int cores) {
    switch (profile) {
      case PerformanceProfile.fast:
        return LlmPrefsState(
          profile: profile,
          ctxLen: 1024,
          threads: min(4, cores),
          temp: 0.7,
          topP: 0.9,
          topK: 40,
          maxTokens: 256,
        );
      case PerformanceProfile.standard:
        return LlmPrefsState(
          profile: profile,
          ctxLen: 2048,
          threads: min(6, cores),
          temp: 0.7,
          topP: 0.9,
          topK: 40,
          maxTokens: 512,
        );
      case PerformanceProfile.quality:
        return LlmPrefsState(
          profile: profile,
          ctxLen: 4096,
          threads: min(8, cores),
          temp: 0.65,
          topP: 0.92,
          topK: 40,
          maxTokens: 768,
        );
      case PerformanceProfile.a54:
        return LlmPrefsState(
          profile: profile,
          ctxLen: 2048,
          threads: min(6, cores),
          temp: 0.7,
          topP: 0.9,
          topK: 40,
          maxTokens: 384,
        );
      case PerformanceProfile.custom:
        return state;
    }
  }

  PerformanceProfile? _autoProfile(Map<String, dynamic> info) {
    final model = (info['model'] as String?)?.toLowerCase() ?? '';
    if (model.contains('a546') || model.contains('a54')) {
      return PerformanceProfile.a54;
    }
    return null;
  }
}

final llmPrefsProvider =
    StateNotifierProvider<LlmPrefsController, LlmPrefsState>((ref) {
  return LlmPrefsController(ref.read(localLlmServiceProvider));
});
