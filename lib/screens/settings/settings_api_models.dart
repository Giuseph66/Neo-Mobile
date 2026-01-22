import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/config/ai_config_store.dart';
import '../../ai/providers/provider_registry.dart';
import '../../llm/llm_prefs.dart';
import '../../llm/model_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neon_card.dart';
import '../../widgets/segmented_tabs.dart';
import '../../widgets/status_badge.dart';
import '../../llm/model_catalog.dart';

class SettingsApiModels extends ConsumerStatefulWidget {
  const SettingsApiModels({super.key});

  @override
  ConsumerState<SettingsApiModels> createState() => _SettingsApiModelsState();
}

class _SettingsApiModelsState extends ConsumerState<SettingsApiModels> {
  int _tabIndex = 0;
  bool? _openAiConnected;
  bool? _geminiConnected;

  final _openAiKeyController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _openAiCustomController = TextEditingController();
  final _geminiCustomController = TextEditingController();

  @override
  void dispose() {
    _openAiKeyController.dispose();
    _geminiKeyController.dispose();
    _openAiCustomController.dispose();
    _geminiCustomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(aiConfigProvider);
    final localState = ref.watch(modelRegistryProvider);
    final prefs = ref.watch(llmPrefsProvider);
    final providers = ref.read(providerRegistryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('API e Modelos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedTabs(
            items: const ['Google Gemini', 'OpenAI', 'Local LLM'],
            selectedIndex: _tabIndex,
            onChanged: (index) => setState(() => _tabIndex = index),
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 0)
            _buildGeminiTab(context, config, providers)
          else if (_tabIndex == 1)
            _buildOpenAiTab(context, config, providers)
          else
            _buildLocalTab(context, localState, prefs, config),
        ],
      ),
    );
  }

  Widget _buildGeminiTab(
    BuildContext context,
    AiConfigState config,
    ProviderRegistry providers,
  ) {
    final provider = providers.geminiProvider;
    final activeModel =
        config.activeModels[AiProviderId.gemini] ?? provider.supportedModels.first;
    final isCustom =
        !provider.supportedModels.contains(activeModel) && activeModel.isNotEmpty;

    if (isCustom && _geminiCustomController.text.isEmpty) {
      _geminiCustomController.text = activeModel;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKeyCard(
          context,
          label: 'Google Gemini',
          keyController: _geminiKeyController,
          keyPresent: config.geminiKeyPresent,
          onSave: () async {
            await ref
                .read(aiConfigProvider.notifier)
                .setGeminiKey(_geminiKeyController.text.trim());
            _showSnack(context, 'API Key salva.');
          },
          status: _geminiConnected,
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          context,
          title: 'Modelos Gemini',
          models: provider.supportedModels,
          currentValue: isCustom ? 'custom' : activeModel,
          onChanged: (value) {
            if (value == 'custom') {
              setState(() {});
            } else {
              _geminiCustomController.clear();
              ref
                  .read(aiConfigProvider.notifier)
                  .setActiveModel(AiProviderId.gemini, value);
            }
          },
          customController: _geminiCustomController,
          onActivate: () async {
            final modelId = _geminiCustomController.text.trim().isNotEmpty
                ? _geminiCustomController.text.trim()
                : activeModel;
            await ref
                .read(aiConfigProvider.notifier)
                .setActiveModel(AiProviderId.gemini, modelId);
            await ref
                .read(aiConfigProvider.notifier)
                .setActiveProvider(AiProviderId.gemini);
            _showSnack(context, 'Gemini ativado.');
          },
          onTest: () async {
            final ok = await provider.testConnection();
            setState(() => _geminiConnected = ok);
          },
          config: config.geminiParams,
          onParamsChanged: (params) => ref
              .read(aiConfigProvider.notifier)
              .setProviderParams(AiProviderId.gemini, params),
          showReasoning: false,
        ),
      ],
    );
  }

  Widget _buildOpenAiTab(
    BuildContext context,
    AiConfigState config,
    ProviderRegistry providers,
  ) {
    final provider = providers.openAiProvider;
    final activeModel =
        config.activeModels[AiProviderId.openai] ?? provider.supportedModels.first;
    final isCustom =
        !provider.supportedModels.contains(activeModel) && activeModel.isNotEmpty;
    final selectedModel = isCustom && _openAiCustomController.text.trim().isNotEmpty
        ? _openAiCustomController.text.trim()
        : activeModel;

    if (isCustom && _openAiCustomController.text.isEmpty) {
      _openAiCustomController.text = activeModel;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKeyCard(
          context,
          label: 'OpenAI',
          keyController: _openAiKeyController,
          keyPresent: config.openAiKeyPresent,
          onSave: () async {
            await ref
                .read(aiConfigProvider.notifier)
                .setOpenAiKey(_openAiKeyController.text.trim());
            _showSnack(context, 'API Key salva.');
          },
          status: _openAiConnected,
        ),
        const SizedBox(height: 12),
        _buildProviderCard(
          context,
          title: 'Modelos OpenAI',
          models: provider.supportedModels,
          currentValue: isCustom ? 'custom' : activeModel,
          onChanged: (value) {
            if (value == 'custom') {
              setState(() {});
            } else {
              _openAiCustomController.clear();
              ref
                  .read(aiConfigProvider.notifier)
                  .setActiveModel(AiProviderId.openai, value);
            }
          },
          customController: _openAiCustomController,
          onActivate: () async {
            final modelId = _openAiCustomController.text.trim().isNotEmpty
                ? _openAiCustomController.text.trim()
                : activeModel;
            await ref
                .read(aiConfigProvider.notifier)
                .setActiveModel(AiProviderId.openai, modelId);
            await ref
                .read(aiConfigProvider.notifier)
                .setActiveProvider(AiProviderId.openai);
            _showSnack(context, 'OpenAI ativado.');
          },
          onTest: () async {
            final ok = await provider.testConnection();
            setState(() => _openAiConnected = ok);
          },
          config: config.openAiParams,
          onParamsChanged: (params) => ref
              .read(aiConfigProvider.notifier)
              .setProviderParams(AiProviderId.openai, params),
          showReasoning: _supportsReasoning(selectedModel),
        ),
      ],
    );
  }

  Widget _buildLocalTab(
    BuildContext context,
    ModelRegistryState modelState,
    LlmPrefsState prefs,
    AiConfigState config,
  ) {
    final localModel = modelState.activeModel;
    final activeProvider = config.activeProvider == AiProviderId.local;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (modelState.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeonCard(
              child: Text(
                'Erro: ${modelState.lastError}',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        NeonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Local LLM (GGUF)',
                    style: TextStyle(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(
                    label: activeProvider ? 'ATIVO' : 'INATIVO',
                    color: activeProvider ? AppColors.success : AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (value) async {
                      if (value == 'import') {
                        await _pickModel(context);
                      } else if (value == 'download') {
                        await _promptDownload(context);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'import',
                        child: Text('Importar modelo'),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: Text('Baixar por URL'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                localModel?.name ?? 'Nenhum modelo ativo',
                style: const TextStyle(color: AppColors.text2),
              ),
              if (localModel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatModelMeta(localModel),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: modelState.activeModelId == null
                        ? null
                        : () async {
                            final ok = await ref
                                .read(modelRegistryProvider.notifier)
                                .loadActiveModel(
                                  prefs.toGenerationParams(),
                                );
                            if (!ok) {
                              _showSnack(
                                context,
                                'Falha ao carregar. Verifique o engine JNI.',
                              );
                            }
                          },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Carregar Modelo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: modelState.activeLoaded
                        ? () => ref
                            .read(modelRegistryProvider.notifier)
                            .unloadModel()
                        : null,
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Descarregar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(aiConfigProvider.notifier)
                          .setActiveProvider(AiProviderId.local);
                      if (modelState.activeModelId != null) {
                        await ref
                            .read(aiConfigProvider.notifier)
                            .setActiveModel(
                              AiProviderId.local,
                              modelState.activeModelId!,
                            );
                      }
                      _showSnack(context, 'Local LLM ativado.');
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Ativar Local'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Modelos recomendados',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Column(
          children: _groupedModels().entries.expand((entry) {
            final header = Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: AppColors.text1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
            final cards = entry.value.map((model) {
              final existing = _findModelByName(modelState, model.fileName);
              final isInstalled = existing != null;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: NeonCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              style: const TextStyle(
                                color: AppColors.text1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${model.quantHint} • ${model.tag}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isInstalled)
                        OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(modelRegistryProvider.notifier)
                                .setActive(existing!.id);
                            await ref
                                .read(aiConfigProvider.notifier)
                                .setActiveModel(
                                  AiProviderId.local,
                                  existing.id,
                                );
                          },
                          child: const Text('Selecionar'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => ref
                              .read(modelRegistryProvider.notifier)
                              .downloadModel(model.url, model.fileName),
                          child: const Text('Baixar'),
                        ),
                    ],
                  ),
                ),
              );
            }).toList();
            return [header, ...cards];
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (modelState.downloadProgress.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloads em andamento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Column(
                children: modelState.downloadProgress.entries.map((entry) {
                  final label =
                      modelState.downloadLabels[entry.key] ?? entry.key;
                  final isIndeterminate = entry.value < 0;
                  final downloaded =
                      modelState.downloadedBytes[entry.key] ?? 0;
                  final total = modelState.totalBytes[entry.key] ?? -1;
                  final hasTotal = total > 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: NeonCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: isIndeterminate
                                ? null
                                : min(1.0, entry.value),
                            backgroundColor: AppColors.surface2,
                            color: AppColors.primary,
                          ),
                          if (!isIndeterminate)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${(entry.value * 100).toStringAsFixed(0)}%'
                                '${hasTotal ? ' • ${_formatBytes(downloaded)} / ${_formatBytes(total)}' : ''}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ),
                          if (isIndeterminate)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                hasTotal
                                    ? '${_formatBytes(downloaded)} / ${_formatBytes(total)}'
                                    : downloaded > 0
                                        ? '${_formatBytes(downloaded)} baixado'
                                        : 'Calculando...',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          'Modelos disponiveis',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (modelState.models.isEmpty)
          const Text(
            'Nenhum modelo importado.',
            style: TextStyle(color: AppColors.muted),
          )
        else
          Column(
            children: modelState.models.map((model) {
              final selected = model.id == modelState.activeModelId;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: NeonCard(
                  selected: selected,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              style: const TextStyle(
                                color: AppColors.text1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatModelMeta(model),
                              style: const TextStyle(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await ref
                              .read(modelRegistryProvider.notifier)
                              .setActive(model.id);
                          await ref.read(aiConfigProvider.notifier).setActiveModel(
                                AiProviderId.local,
                                model.id,
                              );
                        },
                        child: Text(selected ? 'Ativo' : 'Selecionar'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _confirmDelete(context, model),
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildKeyCard(
    BuildContext context, {
    required String label,
    required TextEditingController keyController,
    required bool keyPresent,
    required VoidCallback onSave,
    required bool? status,
  }) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (status == true)
                const StatusBadge(label: 'CONECTADO', color: AppColors.success)
              else if (status == false)
                const StatusBadge(label: 'ERRO', color: AppColors.danger)
              else
                StatusBadge(
                  label: keyPresent ? 'CHAVE OK' : 'SEM CHAVE',
                  color: keyPresent ? AppColors.success : AppColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: keyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.lock),
              label: const Text('Salvar chave'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context, {
    required String title,
    required List<String> models,
    required String currentValue,
    required ValueChanged<String> onChanged,
    required TextEditingController customController,
    required VoidCallback onActivate,
    required VoidCallback onTest,
    required ProviderParams config,
    required ValueChanged<ProviderParams> onParamsChanged,
    required bool showReasoning,
  }) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: currentValue,
            items: [
              ...models.map(
                (model) => DropdownMenuItem(
                  value: model,
                  child: Text(model),
                ),
              ),
              const DropdownMenuItem(
                value: 'custom',
                child: Text('Custom model id'),
              ),
            ],
            onChanged: (value) => onChanged(value ?? models.first),
            decoration: const InputDecoration(labelText: 'Modelo'),
          ),
          if (currentValue == 'custom')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: customController,
                decoration: const InputDecoration(
                  labelText: 'Custom model id',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onTest,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Testar conexao'),
              ),
              ElevatedButton.icon(
                onPressed: onActivate,
                icon: const Icon(Icons.check_circle),
                label: const Text('Ativar Modelo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Configuracoes extras',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Temperature: ${config.temperature.toStringAsFixed(2)}'),
          Slider(
            value: config.temperature,
            min: 0.0,
            max: 1.2,
            onChanged: (value) =>
                onParamsChanged(config.copyWith(temperature: value)),
          ),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Max output tokens',
              hintText: '${config.maxOutputTokens}',
            ),
            onSubmitted: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null) {
                onParamsChanged(config.copyWith(maxOutputTokens: parsed));
              }
            },
          ),
          if (showReasoning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<String>(
                value: config.reasoningEffort ?? 'medium',
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) => onParamsChanged(
                  config.copyWith(reasoningEffort: value),
                ),
                decoration: const InputDecoration(labelText: 'Reasoning effort'),
              ),
            ),
        ],
      ),
    );
  }

  String _formatModelMeta(LlmModel model) {
    final quant = model.quantHint ?? 'GGUF';
    return '${_formatBytes(model.sizeBytes)} | $quant';
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

  Future<void> _pickModel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.gguf')) {
      _showSnack(context, 'Selecione um arquivo .gguf valido.');
      return;
    }
    final pathOrUri = file.path ?? file.identifier;
    if (pathOrUri == null) {
      _showSnack(context, 'Falha ao obter caminho do arquivo.');
      return;
    }
    await ref.read(modelRegistryProvider.notifier).importModel(pathOrUri);
  }

  Future<void> _promptDownload(BuildContext context) async {
    final urlController = TextEditingController();
    final nameController = TextEditingController(text: 'modelo.gguf');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          title: const Text('Baixar por URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(hintText: 'https://...'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'arquivo.gguf'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Baixar'),
            ),
          ],
        );
      },
    );
    if (ok != true) {
      return;
    }
    await ref.read(modelRegistryProvider.notifier).downloadModel(
          urlController.text.trim(),
          nameController.text.trim(),
        );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Map<String, List<PredefinedModel>> _groupedModels() {
    final map = <String, List<PredefinedModel>>{};
    for (final model in kPredefinedModels) {
      map.putIfAbsent(model.tag, () => []).add(model);
    }
    return map;
  }

  LlmModel? _findModelByName(ModelRegistryState state, String fileName) {
    for (final model in state.models) {
      if (model.name == fileName) {
        return model;
      }
    }
    return null;
  }

  Future<void> _confirmDelete(BuildContext context, LlmModel model) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Remover modelo'),
        content: Text('Deseja apagar ${model.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    final removed = await ref
        .read(modelRegistryProvider.notifier)
        .deleteModel(model.id);
    if (!removed) {
      _showSnack(context, 'Falha ao remover modelo.');
    }
  }

  bool _supportsReasoning(String modelId) {
    if (modelId.trim().isEmpty) {
      return false;
    }
    final id = modelId.toLowerCase();
    return id.startsWith('o') || id.contains('gpt-5');
  }
}
