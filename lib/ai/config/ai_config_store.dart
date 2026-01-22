import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProviderId { local, openai, gemini }

class ProviderParams {
  const ProviderParams({
    required this.temperature,
    required this.maxOutputTokens,
    this.reasoningEffort,
  });

  final double temperature;
  final int maxOutputTokens;
  final String? reasoningEffort;

  ProviderParams copyWith({
    double? temperature,
    int? maxOutputTokens,
    String? reasoningEffort,
  }) {
    return ProviderParams(
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'maxOutputTokens': maxOutputTokens,
      'reasoningEffort': reasoningEffort,
    };
  }

  static ProviderParams fromMap(Map<String, dynamic> map) {
    return ProviderParams(
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxOutputTokens: (map['maxOutputTokens'] as num?)?.toInt() ?? 512,
      reasoningEffort: map['reasoningEffort'] as String?,
    );
  }
}

class AiConfigState {
  const AiConfigState({
    required this.activeProvider,
    required this.activeModels,
    required this.openAiParams,
    required this.geminiParams,
    this.openAiKeyPresent = false,
    this.geminiKeyPresent = false,
  });

  final AiProviderId activeProvider;
  final Map<AiProviderId, String> activeModels;
  final ProviderParams openAiParams;
  final ProviderParams geminiParams;
  final bool openAiKeyPresent;
  final bool geminiKeyPresent;

  AiConfigState copyWith({
    AiProviderId? activeProvider,
    Map<AiProviderId, String>? activeModels,
    ProviderParams? openAiParams,
    ProviderParams? geminiParams,
    bool? openAiKeyPresent,
    bool? geminiKeyPresent,
  }) {
    return AiConfigState(
      activeProvider: activeProvider ?? this.activeProvider,
      activeModels: activeModels ?? this.activeModels,
      openAiParams: openAiParams ?? this.openAiParams,
      geminiParams: geminiParams ?? this.geminiParams,
      openAiKeyPresent: openAiKeyPresent ?? this.openAiKeyPresent,
      geminiKeyPresent: geminiKeyPresent ?? this.geminiKeyPresent,
    );
  }
}

class AiConfigStore extends StateNotifier<AiConfigState> {
  AiConfigStore() : super(_defaultState());

  static const _secureStorage = FlutterSecureStorage();

  static AiConfigState _defaultState() {
    return const AiConfigState(
      activeProvider: AiProviderId.local,
      activeModels: {},
      openAiParams: ProviderParams(temperature: 0.7, maxOutputTokens: 512),
      geminiParams: ProviderParams(temperature: 0.7, maxOutputTokens: 512),
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final providerRaw = prefs.getString('ai_active_provider');
    final activeProvider = AiProviderId.values.firstWhere(
      (p) => p.name == providerRaw,
      orElse: () => AiProviderId.local,
    );
    final modelsRaw = prefs.getString('ai_active_models');
    final modelsMap = <AiProviderId, String>{};
    if (modelsRaw != null) {
      final decoded = jsonDecode(modelsRaw) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        final provider = AiProviderId.values.firstWhere(
          (p) => p.name == key,
          orElse: () => AiProviderId.local,
        );
        if (value is String) {
          modelsMap[provider] = value;
        }
      });
    }
    final openAiParams = _loadParams(prefs, 'openai');
    final geminiParams = _loadParams(prefs, 'gemini');
    final openAiKeyPresent = await _secureStorage.read(key: 'openai_key') != null;
    final geminiKeyPresent = await _secureStorage.read(key: 'gemini_key') != null;

    state = state.copyWith(
      activeProvider: activeProvider,
      activeModels: modelsMap,
      openAiParams: openAiParams,
      geminiParams: geminiParams,
      openAiKeyPresent: openAiKeyPresent,
      geminiKeyPresent: geminiKeyPresent,
    );
  }

  Future<void> setActiveProvider(AiProviderId provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_active_provider', provider.name);
    state = state.copyWith(activeProvider: provider);
  }

  Future<void> setActiveModel(AiProviderId provider, String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    final models = Map<AiProviderId, String>.from(state.activeModels);
    models[provider] = modelId;
    await prefs.setString('ai_active_models', jsonEncode(_encodeModels(models)));
    state = state.copyWith(activeModels: models);
  }

  Future<void> setProviderParams(AiProviderId provider, ProviderParams params) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_params_${provider.name}', jsonEncode(params.toMap()));
    if (provider == AiProviderId.openai) {
      state = state.copyWith(openAiParams: params);
    } else if (provider == AiProviderId.gemini) {
      state = state.copyWith(geminiParams: params);
    }
  }

  Future<void> setOpenAiKey(String key) async {
    await _secureStorage.write(key: 'openai_key', value: key);
    state = state.copyWith(openAiKeyPresent: key.isNotEmpty);
  }

  Future<void> setGeminiKey(String key) async {
    await _secureStorage.write(key: 'gemini_key', value: key);
    state = state.copyWith(geminiKeyPresent: key.isNotEmpty);
  }

  Future<String?> getOpenAiKey() => _secureStorage.read(key: 'openai_key');

  Future<String?> getGeminiKey() => _secureStorage.read(key: 'gemini_key');

  static ProviderParams _loadParams(SharedPreferences prefs, String key) {
    final raw = prefs.getString('ai_params_$key');
    if (raw == null) {
      return const ProviderParams(temperature: 0.7, maxOutputTokens: 512);
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ProviderParams.fromMap(decoded);
  }

  static Map<String, String> _encodeModels(Map<AiProviderId, String> models) {
    return models.map((key, value) => MapEntry(key.name, value));
  }
}

final aiConfigProvider =
    StateNotifierProvider<AiConfigStore, AiConfigState>((ref) {
  return AiConfigStore();
});
