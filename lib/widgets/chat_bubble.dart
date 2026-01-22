import 'package:flutter/material.dart';

import '../llm/generation_controller.dart';
import '../theme/app_colors.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? AppColors.surface1 : AppColors.surface0;
    final borderColor = isUser ? AppColors.outline1 : AppColors.outline0;

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          message.text.isEmpty && message.streaming
              ? '...'
              : message.text,
          style: const TextStyle(color: AppColors.text1, height: 1.35),
        ),
      ),
    );
  }
}
