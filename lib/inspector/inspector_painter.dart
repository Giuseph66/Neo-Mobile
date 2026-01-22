import 'package:flutter/material.dart';

import 'inspector_hit_test.dart';
import 'inspector_node.dart';

class InspectorPainter extends CustomPainter {
  InspectorPainter({
    required this.nodes,
    required this.selected,
    required this.showLabels,
  });

  final List<InspectorNode> nodes;
  final InspectorNode? selected;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    for (final node in nodes) {
      final color = colorForCategory(node.category);
      final rect = clampRect(node.rect, size);
      if (rect.isEmpty) {
        continue;
      }

      final isSelected = selected?.id == node.id;
      final strokeWidth = isSelected ? 3.0 : 1.5;
      final paint = Paint()
        ..color = translucent(color, isSelected ? 0.95 : 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      final fillPaint = Paint()
        ..color = translucent(color, isSelected ? 0.18 : 0.08)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, paint);

      if (showLabels) {
        final label = node.title;
        final maxWidth = rect.width - 4;
        if (maxWidth <= 0) {
          continue;
        }
        labelPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            backgroundColor: translucent(color, 0.95),
          ),
        );
        labelPainter.layout(maxWidth: maxWidth);
        final offset = Offset(rect.left + 2, rect.top + 2);
        labelPainter.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant InspectorPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.selected?.id != selected?.id ||
        oldDelegate.showLabels != showLabels;
  }
}
