import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/config/ai_config_store.dart';
import '../ai/providers/chat_provider.dart';
import '../ai/providers/provider_registry.dart';
import '../llm/generation_controller.dart';
import '../llm/local_llm_service.dart';
import '../llm/llm_prefs.dart';
import '../llm/model_registry.dart';
import '../screens/settings/settings_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/composer_bar.dart';
import '../widgets/neon_card.dart';
import '../widgets/status_badge.dart';

class HomeChatScreen extends ConsumerStatefulWidget {
  const HomeChatScreen({super.key});

  @override
  ConsumerState<HomeChatScreen> createState() => _HomeChatScreenState();
}

class _HomeChatScreenState extends ConsumerState<HomeChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _perfTimer;
  bool _showPerf = false;
  Map<String, dynamic>? _perfStats;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _perfTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(generationControllerProvider);
    final modelState = ref.watch(modelRegistryProvider);
    final config = ref.watch(aiConfigProvider);
    final providers = ref.watch(providerRegistryProvider);
    final prefs = ref.watch(llmPrefsProvider);
    final activeProvider = config.activeProvider;
    final provider = providers.byId(activeProvider.name);
    final isLocal = activeProvider == AiProviderId.local;
    final modelLabel =
        _resolveModelLabel(activeProvider, provider, config, modelState);
    final providerStatus =
        _resolveProviderStatus(activeProvider, config, modelState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat Local'),
            if (chatState.tokensPerSecond > 0)
              Text(
                '${chatState.tokensPerSecond.toStringAsFixed(1)} tok/s',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showPerf ? 'Ocultar desempenho' : 'Mostrar desempenho',
            onPressed: _togglePerf,
            icon: Icon(_showPerf ? Icons.speed : Icons.speed_outlined),
          ),
          IconButton(
            tooltip: 'Detalhes do desempenho',
            onPressed: () => _showPerfDetails(prefs),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (providerStatus.needsAttention)
            Padding(
              padding: const EdgeInsets.all(12),
              child: NeonCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerStatus.title,
                            style: const TextStyle(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            providerStatus.message,
                            style: TextStyle(color: AppColors.text2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      child: const Text('Configurar'),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  label: provider.displayName,
                  color: AppColors.primary,
                ),
                if (modelLabel.isNotEmpty)
                  StatusBadge(
                    label: modelLabel,
                    color: AppColors.primary2,
                  ),
                StatusBadge(
                  label: providerStatus.title,
                  color: providerStatus.color,
                ),
              ],
            ),
          ),
          if (_showPerf) _buildPerfCard(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: chatState.messages[index]);
              },
            ),
          ),
          ComposerBar(
            controller: _controller,
            isGenerating: chatState.isGenerating,
            onSend: () {
              if (isLocal) {
                if (modelState.activeModelId == null) {
                  _showSnack('Selecione um modelo local primeiro.');
                  return;
                }
                if (!modelState.activeLoaded) {
                  _showSnack('Carregue o modelo antes de gerar.');
                  return;
                }
              } else if (activeProvider == AiProviderId.openai &&
                  !config.openAiKeyPresent) {
                _showSnack('Configure a API key da OpenAI.');
                return;
              } else if (activeProvider == AiProviderId.gemini &&
                  !config.geminiKeyPresent) {
                _showSnack('Configure a API key do Gemini.');
                return;
              }
              ref
                  .read(generationControllerProvider.notifier)
                  .sendPrompt(_controller.text);
              _controller.clear();
            },
            onStop: () =>
                ref.read(generationControllerProvider.notifier).stop(),
            onClear: () =>
                ref.read(generationControllerProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }

  String _resolveModelLabel(
    AiProviderId providerId,
    IChatProvider provider,
    AiConfigState config,
    ModelRegistryState modelState,
  ) {
    if (providerId == AiProviderId.local) {
      return modelState.activeModel?.name ??
          config.activeModels[AiProviderId.local] ??
          'Sem modelo';
    }
    return config.activeModels[providerId] ?? provider.supportedModels.first;
  }

  _ProviderStatus _resolveProviderStatus(
    AiProviderId providerId,
    AiConfigState config,
    ModelRegistryState modelState,
  ) {
    if (providerId == AiProviderId.local) {
      if (modelState.activeModelId == null) {
        return const _ProviderStatus(
          title: 'SEM MODELO',
          color: AppColors.danger,
          needsAttention: true,
          message: 'Importe ou baixe um modelo GGUF para iniciar.',
        );
      }
      if (!modelState.activeLoaded) {
        return const _ProviderStatus(
          title: 'PENDENTE',
          color: AppColors.primary,
          needsAttention: false,
          message: 'Carregue o modelo para iniciar a geracao.',
        );
      }
      return const _ProviderStatus(
        title: 'ATIVADO',
        color: AppColors.success,
        needsAttention: false,
        message: 'Modelo local ativo.',
      );
    }
    final keyPresent = providerId == AiProviderId.openai
        ? config.openAiKeyPresent
        : config.geminiKeyPresent;
    if (!keyPresent) {
      return const _ProviderStatus(
        title: 'SEM CHAVE',
        color: AppColors.danger,
        needsAttention: true,
        message: 'Adicione a API key para usar este provider.',
      );
    }
    return const _ProviderStatus(
      title: 'CONECTADO',
      color: AppColors.success,
      needsAttention: false,
      message: 'Provider remoto ativo.',
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showPerfDetails(LlmPrefsState prefs) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          title: const Text('Desempenho atual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Perfil: ${_profileLabel(prefs.profile)}'),
              const SizedBox(height: 8),
              Text('Contexto: ${prefs.ctxLen}'),
              Text('Threads: ${prefs.threads}'),
              Text('Temperatura: ${prefs.temp.toStringAsFixed(2)}'),
              Text('Top P: ${prefs.topP.toStringAsFixed(2)}'),
              Text('Top K: ${prefs.topK}'),
              Text('Max tokens: ${prefs.maxTokens}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  String _profileLabel(PerformanceProfile profile) {
    switch (profile) {
      case PerformanceProfile.fast:
        return 'Rapido';
      case PerformanceProfile.standard:
        return 'Padrao';
      case PerformanceProfile.quality:
        return 'Qualidade';
      case PerformanceProfile.a54:
        return 'A54 (8GB)';
      case PerformanceProfile.custom:
        return 'Personalizado';
    }
  }

  void _togglePerf() {
    setState(() {
      _showPerf = !_showPerf;
    });
    if (_showPerf) {
      _startPerfPolling();
    } else {
      _perfTimer?.cancel();
      _perfTimer = null;
    }
  }

  void _startPerfPolling() {
    _perfTimer?.cancel();
    _fetchPerfStats();
    _perfTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _fetchPerfStats(),
    );
  }

  Future<void> _fetchPerfStats() async {
    final service = ref.read(localLlmServiceProvider);
    final stats = await service.getProcessStats();
    if (!mounted) {
      return;
    }
    setState(() {
      _perfStats = stats;
    });
  }

  Widget _buildPerfCard() {
    final stats = _perfStats ?? {};
    final cpu = (stats['cpuPercent'] as num?)?.toDouble() ?? 0.0;
    final pssKb = (stats['pssKb'] as num?)?.toInt() ?? 0;
    final rssKb = (stats['rssKb'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CPU (app): ${cpu.toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.text1),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Memoria app: ${_formatMb(pssKb)}',
                    style: const TextStyle(color: AppColors.text1),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Memoria RAM: ${_formatMb(rssKb)}',
                    style: const TextStyle(color: AppColors.text1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Memoria app (PSS) = uso estimado; Memoria RAM (RSS) = uso fisico.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMb(int kb) {
    if (kb <= 0) {
      return '0 MB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _ProviderStatus {
  const _ProviderStatus({
    required this.title,
    required this.color,
    required this.needsAttention,
    required this.message,
  });

  final String title;
  final Color color;
  final bool needsAttention;
  final String message;
}
