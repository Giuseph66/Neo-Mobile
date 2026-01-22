import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../llm/llm_prefs.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neon_card.dart';

class SettingsPerformance extends ConsumerWidget {
  const SettingsPerformance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(llmPrefsProvider);
    final controller = ref.read(llmPrefsProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desempenho', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: PerformanceProfile.values.map((profile) {
              final selected = prefs.profile == profile;
              return SizedBox(
                width: 180,
                child: InkWell(
                  onTap: () => controller.setProfile(profile),
                  child: NeonCard(
                    selected: selected,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profileLabel(profile),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _profileHint(profile),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (prefs.profile == PerformanceProfile.custom)
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajustes personalizados',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NumberField(
                    label: 'Context length',
                    value: prefs.ctxLen,
                    onChanged: (value) => controller.updateParams(ctxLen: value),
                  ),
                  _NumberField(
                    label: 'Threads',
                    value: prefs.threads,
                    onChanged: (value) =>
                        controller.updateParams(threads: value),
                  ),
                  _NumberField(
                    label: 'Top K',
                    value: prefs.topK,
                    onChanged: (value) => controller.updateParams(topK: value),
                  ),
                  _NumberField(
                    label: 'Max tokens',
                    value: prefs.maxTokens,
                    onChanged: (value) =>
                        controller.updateParams(maxTokens: value),
                  ),
                  const SizedBox(height: 12),
                  _SliderField(
                    label: 'Temperature',
                    value: prefs.temp,
                    min: 0.2,
                    max: 1.2,
                    onChanged: (value) => controller.updateParams(temp: value),
                  ),
                  _SliderField(
                    label: 'Top P',
                    value: prefs.topP,
                    min: 0.5,
                    max: 1.0,
                    onChanged: (value) => controller.updateParams(topP: value),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await controller.save();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ajustes salvos.')),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            )
          else
            const Text(
              'Selecione "Personalizado" para ajustar manualmente.',
              style: TextStyle(color: AppColors.muted),
            ),
        ],
      ),
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

  String _profileHint(PerformanceProfile profile) {
    switch (profile) {
      case PerformanceProfile.fast:
        return 'Mais leve e rapido.';
      case PerformanceProfile.standard:
        return 'Equilibrio geral.';
      case PerformanceProfile.quality:
        return 'Melhor qualidade.';
      case PerformanceProfile.a54:
        return 'Preset otimizado para Galaxy A54.';
      case PerformanceProfile.custom:
        return 'Ajuste manual.';
    }
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            return;
          }
          final parsed = int.tryParse(_controller.text);
          if (parsed != null) {
            widget.onChanged(parsed);
          }
        },
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) {
              widget.onChanged(parsed);
            }
          },
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
