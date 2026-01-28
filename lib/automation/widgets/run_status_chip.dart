import 'package:flutter/material.dart';
import '../models/automation_models.dart';

class RunStatusChip extends StatelessWidget {
  final AutomationRunStatus status;

  const RunStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case AutomationRunStatus.success:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        label = 'Sucesso';
        break;
      case AutomationRunStatus.failed:
        color = Colors.red;
        icon = Icons.error_outline;
        label = 'Falha';
        break;
      case AutomationRunStatus.running:
        color = Colors.blue;
        icon = Icons.pending_outlined;
        label = 'Executando';
        break;
      case AutomationRunStatus.cancelled:
        color = Colors.grey;
        icon = Icons.cancel_outlined;
        label = 'Cancelado';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
