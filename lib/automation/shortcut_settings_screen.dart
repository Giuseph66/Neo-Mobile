import 'package:flutter/material.dart';

import 'gesture_models.dart';
import 'key_combos.dart';
import 'shortcut_controller.dart';
import 'workflow_editor_screen.dart';

class ShortcutSettingsScreen extends StatelessWidget {
  const ShortcutSettingsScreen({
    super.key,
    required this.controller,
  });

  final ShortcutController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atalhos e Automacao'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final workflows = controller.workflows;
          if (workflows.isEmpty) {
            return const Center(
              child: Text('Nenhum workflow configurado.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: workflows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final workflow = workflows[index];
              return _WorkflowCard(
                workflow: workflow,
                comboLabel: comboLabelFor(workflow.keyCombo),
                onRun: () => controller.runWorkflow(workflow.id),
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WorkflowEditorScreen(
                      controller: controller,
                      workflow: workflow,
                    ),
                  ),
                ),
                onDelete: () => controller.removeWorkflow(workflow.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkflowEditorScreen(controller: controller),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo workflow'),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.workflow,
    required this.comboLabel,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  final ShortcutWorkflow workflow;
  final String comboLabel;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workflow.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text('Atalho: $comboLabel'),
            const SizedBox(height: 4),
            Text('Acoes: ${workflow.actions.length}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: workflow.actions.isEmpty ? null : onRun,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Executar'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Remover'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
