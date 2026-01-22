import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../llm/llm_prefs.dart';
import '../../llm/model_catalog.dart';
import '../../llm/model_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neon_card.dart';
import '../../widgets/status_badge.dart';

class SettingsApiModels extends ConsumerWidget {
  const SettingsApiModels({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelRegistryProvider);
    final prefs = ref.watch(llmPrefsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modelos locais', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
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
                    _buildStatus(modelState),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) async {
                        if (value == 'import') {
                          await _pickModel(context, ref);
                        } else if (value == 'download') {
                          await _promptDownload(context, ref);
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
                  modelState.activeModel?.name ?? 'Nenhum modelo ativo',
                  style: const TextStyle(color: AppColors.text2),
                ),
                if (modelState.activeModel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatModelMeta(modelState.activeModel!),
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
                          onPressed: () => ref
                              .read(modelRegistryProvider.notifier)
                              .setActive(existing!.id),
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
                                  style:
                                      const TextStyle(color: AppColors.muted),
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
                          onPressed: () => ref
                              .read(modelRegistryProvider.notifier)
                              .setActive(model.id),
                          child: Text(selected ? 'Ativo' : 'Selecionar'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              _confirmDelete(context, ref, model),
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
      ),
    );
  }

  Widget _buildStatus(ModelRegistryState state) {
    if (state.activeModelId == null) {
      return const StatusBadge(label: 'SEM MODELO', color: AppColors.danger);
    }
    if (!state.activeLoaded) {
      return const StatusBadge(label: 'PENDENTE', color: AppColors.primary);
    }
    return const StatusBadge(label: 'ATIVADO', color: AppColors.success);
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

  Future<void> _pickModel(BuildContext context, WidgetRef ref) async {
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

  Future<void> _promptDownload(BuildContext context, WidgetRef ref) async {
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LlmModel model,
  ) async {
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
}
