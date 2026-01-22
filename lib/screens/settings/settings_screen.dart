import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import 'settings_api_models.dart';
import 'settings_performance.dart';

final settingsSectionProvider = StateProvider<int>((ref) => 0);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsSectionProvider);
    final sections = const [
      'API e Modelos',
      'Desempenho',
      'Privacidade',
      'Ajuda',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final content = _sectionContent(selected);

        if (isWide) {
          return Scaffold(
            appBar: AppBar(title: const Text('Configuracoes')),
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: AppColors.surface1,
                  selectedIndex: selected,
                  onDestinationSelected: (index) => ref
                      .read(settingsSectionProvider.notifier)
                      .state = index,
                  destinations: sections
                      .map(
                        (label) => NavigationRailDestination(
                          icon: const Icon(Icons.circle),
                          label: Text(label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1, color: AppColors.outline0),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Configuracoes')),
          drawer: Drawer(
            backgroundColor: AppColors.surface1,
            child: ListView.builder(
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final isSelected = selected == index;
                return ListTile(
                  selected: isSelected,
                  title: Text(sections[index]),
                  onTap: () {
                    ref.read(settingsSectionProvider.notifier).state = index;
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          body: content,
        );
      },
    );
  }

  Widget _sectionContent(int index) {
    switch (index) {
      case 0:
        return const SettingsApiModels();
      case 1:
        return const SettingsPerformance();
      case 2:
        return const _PlaceholderSection(
          title: 'Privacidade',
          body: 'Sem envio de dados. Tudo roda localmente.',
        );
      case 3:
        return const _PlaceholderSection(
          title: 'Ajuda',
          body: 'Selecione um provider e carregue o modelo.',
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: AppColors.text2)),
        ],
      ),
    );
  }
}
