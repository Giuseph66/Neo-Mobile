import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ComposerBar extends StatelessWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.onClear,
    required this.isGenerating,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onClear;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: const Border(top: BorderSide(color: AppColors.outline0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: AppColors.text1),
                  decoration: const InputDecoration(
                    hintText: 'Digite sua mensagem...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isGenerating ? null : onSend,
                child: const Text('Enviar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text(
                  'Limpar',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
              if (isGenerating)
                OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop, color: AppColors.danger),
                  label: const Text(
                    'Parar',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
