import 'package:flutter/material.dart';
import '../../inspector_accessibility/domain/models/ui_node.dart';
import '../../theme/app_colors.dart';

class ElementPreview extends StatelessWidget {
  final UiNode node;

  const ElementPreview({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.text != null && node.text!.isNotEmpty)
            Text(
              node.text!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.text1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            node.className,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (node.clickable)
                _Chip(
                  label: 'Clicável',
                  color: AppColors.success,
                ),
              if (node.scrollable)
                _Chip(
                  label: 'Scrollável',
                  color: AppColors.primary,
                ),
              if (node.enabled)
                _Chip(
                  label: 'Habilitado',
                  color: AppColors.text2,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

