import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class PermissionStatusCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isEnabled;
  final VoidCallback onAction;
  final IconData icon;

  const PermissionStatusCard({
    super.key,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.onAction,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isEnabled ? Colors.green : Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Icon(
                  isEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isEnabled ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: AppColors.text2.withOpacity(0.8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnabled ? AppColors.surface2 : AppColors.primary,
                  foregroundColor: isEnabled ? AppColors.text1 : Colors.black,
                ),
                child: Text(isEnabled ? 'Configurado' : 'Configurar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
