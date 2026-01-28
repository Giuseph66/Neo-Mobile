import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../../theme/app_colors.dart';

class StepCard extends StatelessWidget {
  final AutomationStep step;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;

  const StepCard({
    super.key,
    required this.step,
    this.onDelete,
    this.onEdit,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.surface2, width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(step.type).withOpacity(0.1),
          child: Icon(_getTypeIcon(step.type), color: _getTypeColor(step.type), size: 20),
        ),
        title: Text(
          _getTypeLabel(step.type),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          _getStepSummary(step),
          style: TextStyle(fontSize: 12, color: AppColors.text2.withOpacity(0.8)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: onDelete,
            ),
            const Icon(Icons.drag_handle, color: AppColors.text2),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(AutomationStepType type) {
    switch (type) {
      case AutomationStepType.openApp: return Icons.launch;
      case AutomationStepType.tapElement: return Icons.touch_app;
      case AutomationStepType.inputText: return Icons.keyboard;
      case AutomationStepType.waitForElement: return Icons.hourglass_empty;
      case AutomationStepType.delay: return Icons.timer_outlined;
      case AutomationStepType.back: return Icons.arrow_back;
      case AutomationStepType.home: return Icons.home;
      case AutomationStepType.swipe: return Icons.swipe;
      case AutomationStepType.recents: return Icons.history;
    }
  }

  Color _getTypeColor(AutomationStepType type) {
    switch (type) {
      case AutomationStepType.openApp: return Colors.blue;
      case AutomationStepType.tapElement: return Colors.green;
      case AutomationStepType.inputText: return Colors.purple;
      case AutomationStepType.waitForElement: return Colors.orange;
      case AutomationStepType.delay: return Colors.amber;
      case AutomationStepType.back: return Colors.grey;
      case AutomationStepType.home: return Colors.grey;
      case AutomationStepType.swipe: return Colors.teal;
      case AutomationStepType.recents: return Colors.blueGrey;
    }
  }

  String _getTypeLabel(AutomationStepType type) {
    switch (type) {
      case AutomationStepType.openApp: return 'Abrir App';
      case AutomationStepType.tapElement: return 'Clicar Elemento';
      case AutomationStepType.inputText: return 'Digitar Texto';
      case AutomationStepType.waitForElement: return 'Aguardar Elemento';
      case AutomationStepType.delay: return 'Esperar';
      case AutomationStepType.back: return 'Voltar';
      case AutomationStepType.home: return 'Home';
      case AutomationStepType.swipe: return 'Deslizar';
      case AutomationStepType.recents: return 'Recent Apps';
    }
  }

  String _getStepSummary(AutomationStep step) {
    switch (step.type) {
      case AutomationStepType.openApp:
        return 'App: ${step.params['package'] ?? 'N/A'}';
      case AutomationStepType.tapElement:
        return 'Seletor: ${step.selectorRef ?? 'N/A'}';
      case AutomationStepType.inputText:
        return 'Texto: "${step.params['text'] ?? ''}" no campo ${step.selectorRef ?? ''}';
      case AutomationStepType.waitForElement:
        return 'Esperar por: ${step.selectorRef ?? 'N/A'}';
      case AutomationStepType.delay:
        return 'Duração: ${step.params['duration_ms'] ?? 1000}ms';
      case AutomationStepType.back:
        return 'Ação do sistema Voltar';
      case AutomationStepType.home:
        return 'Ação do sistema Home';
      case AutomationStepType.swipe:
        return 'Direção: ${step.params['direction'] ?? 'N/A'}';
      case AutomationStepType.recents:
        return 'Ação do sistema Recent Apps';
    }
  }
}
