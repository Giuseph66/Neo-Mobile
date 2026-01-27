import 'package:flutter/material.dart';
import '../../inspector_accessibility/domain/models/ui_node.dart';
import '../../theme/app_colors.dart';

class UiSnapshotPainter extends CustomPainter {
  final List<UiNode> nodes;
  final String? focusedNodeId;

  UiSnapshotPainter({
    required this.nodes,
    this.focusedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      final isFocused = node.id == focusedNodeId;
      final rect = node.bounds;
      
      // Cor baseada em propriedades
      Color color = AppColors.primary;
      if (node.clickable) color = AppColors.success;
      if (isFocused) color = Colors.red;

      final paint = Paint()
        ..color = color.withOpacity(isFocused ? 0.8 : 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFocused ? 3.0 : 1.0;

      final fillPaint = Paint()
        ..color = color.withOpacity(isFocused ? 0.2 : 0.05)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, paint);
      
      // Desenhar ID ou texto resumido se focado
      if (isFocused || nodes.length < 20) {
        final labelText = node.text != null 
            ? (node.text!.length > 15 ? '${node.text!.substring(0, 15)}...' : node.text!)
            : node.className.split('.').last;

        final textPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              backgroundColor: color.withOpacity(0.8),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(canvas, Offset(rect.left, rect.top - 12));
      }
    }
  }

  @override
  bool shouldRepaint(covariant UiSnapshotPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.focusedNodeId != focusedNodeId;
  }
}
