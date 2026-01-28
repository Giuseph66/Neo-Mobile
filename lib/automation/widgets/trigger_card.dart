import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../../theme/app_colors.dart';

class TriggerCard extends StatelessWidget {
  final AutomationTrigger trigger;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onToggle;

  const TriggerCard({
    super.key,
    required this.trigger,
    this.onDelete,
    this.onEdit,
    this.onToggle,
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.alarm, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTriggerLabel(trigger.type),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _getTriggerSummary(trigger),
                        style: TextStyle(fontSize: 12, color: AppColors.text2.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: trigger.enabled,
                  onChanged: onToggle,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Excluir', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTriggerLabel(AutomationTriggerType type) {
    switch (type) {
      case AutomationTriggerType.daily: return 'Diário';
      case AutomationTriggerType.weekly: return 'Semanal';
      case AutomationTriggerType.interval: return 'Intervalo';
      case AutomationTriggerType.once: return 'Uma vez';
    }
  }

  String _getTriggerSummary(AutomationTrigger trigger) {
    final sb = StringBuffer();
    if (trigger.timeOfDay != null) {
      sb.write('Às ${trigger.timeOfDay}');
    }
    if (trigger.daysOfWeek != null && trigger.daysOfWeek!.isNotEmpty) {
      final days = trigger.daysOfWeek!.map((d) => _getDayName(d)).join(', ');
      sb.write(' nos dias: $days');
    }
    if (sb.isEmpty) return 'Sem configuração';
    return sb.toString();
  }

  String _getDayName(int day) {
    switch (day) {
      case 1: return 'Seg';
      case 2: return 'Ter';
      case 3: return 'Qua';
      case 4: return 'Qui';
      case 5: return 'Sex';
      case 6: return 'Sáb';
      case 7: return 'Dom';
      default: return '';
    }
  }
}
