import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/neon_card.dart';
import 'home_chat_screen.dart';
import 'overlay_inspector_screen.dart';

class AppHubScreen extends StatelessWidget {
  const AppHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neurelix Lab'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Escolha um modulo',
            style: TextStyle(
              color: AppColors.text1,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          _HubCard(
            title: 'Chat Local LLM',
            description:
                'Chat offline com streaming de tokens e modelos GGUF locais.',
            cta: 'Abrir Chat',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HomeChatScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _HubCard(
            title: 'Overlay + Inspector',
            description:
                'Ferramentas internas para overlay e inspeccao de widgets do app.',
            cta: 'Abrir Inspector',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OverlayInspectorScreen()),
            ),
          ),
          /*
          const SizedBox(height: 12),
          _HubCard(
            title: 'Inspector Accessibility',
            description:
                'Fluxo de permissoes e ferramentas do inspector de acessibilidade.',
            cta: 'Abrir Fluxo',
            onTap: () => Navigator.of(context).pushNamed('/permissions'),
          ),
           */
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.description,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String description;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text1,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: onTap, child: Text(cta)),
          ),
        ],
      ),
    );
  }
}
