import 'package:flutter/material.dart';
import '../ai/config/ai_config_store.dart';
import '../theme/app_colors.dart';

class ModelIcon extends StatelessWidget {
  final AiProviderId providerId;
  final double size;
  final Color? color;

  const ModelIcon({
    super.key,
    required this.providerId,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    switch (providerId) {
      case AiProviderId.gemini:
        return Icon(
          Icons.auto_awesome,
          size: size,
          color: color ?? Colors.blueAccent,
        );
      case AiProviderId.openai:
        return Icon(
          Icons.bolt,
          size: size,
          color: color ?? Colors.greenAccent,
        );
      case AiProviderId.local:
      default:
        return Icon(
          Icons.terminal,
          size: size,
          color: color ?? AppColors.primary,
        );
    }
  }
}
