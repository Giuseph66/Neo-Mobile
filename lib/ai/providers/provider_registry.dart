import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../llm/llm_prefs.dart';
import '../../llm/local_llm_service.dart';
import '../../llm/model_registry.dart';
import '../config/ai_config_store.dart';
import 'chat_provider.dart';
import 'gemini_provider.dart';
import 'local_provider.dart';
import 'openai_provider.dart';

class ProviderRegistry {
  ProviderRegistry({
    required this.localProvider,
    required this.openAiProvider,
    required this.geminiProvider,
  });

  final LocalProvider localProvider;
  final OpenAiProvider openAiProvider;
  final GeminiProvider geminiProvider;

  IChatProvider byId(String id) {
    switch (id) {
      case 'openai':
        return openAiProvider;
      case 'gemini':
        return geminiProvider;
      case 'local':
      default:
        return localProvider;
    }
  }
}

final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final config = ref.read(aiConfigProvider.notifier);
  final localService = ref.read(localLlmServiceProvider);
  final prefs = ref.read(llmPrefsProvider.notifier);
  return ProviderRegistry(
    localProvider: LocalProvider(localService, prefs),
    openAiProvider: OpenAiProvider(config),
    geminiProvider: GeminiProvider(config),
  );
});
