import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neon_card.dart';

class RoutineCard extends StatelessWidget {
  final AutomationRoutine routine;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onEdit;

  const RoutineCard({
    super.key,
    required this.routine,
    this.onTap,
    this.onPlay,
    this.onToggle,
    this.onDelete,
    this.onDuplicate,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(Icons.bolt, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.text1,
                      ),
                    ),
                    if (routine.targetAppPackage != null)
                      Text(
                        routine.targetAppPackage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.text2.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Switch(
                value: routine.enabled,
                onChanged: onToggle,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (routine.description != null && routine.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                routine.description!,
                style: const TextStyle(color: AppColors.text2, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: 'Agendamentos: 0', // TODO: Get from DB
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.list,
                    label: 'Passos: 0', // TODO: Get from DB
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: onPlay,
                    tooltip: 'Rodar agora',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') onDelete?.call();
                      if (value == 'duplicate') onDuplicate?.call();
                      if (value == 'edit') onEdit?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar'),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.text2),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.text2),
          ),
        ],
      ),
    );
  }
}
