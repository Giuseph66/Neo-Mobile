import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'llm/generation_controller.dart';
import 'llm/llm_prefs.dart';
import 'llm/model_registry.dart';
import 'screens/app_hub_screen.dart';
import 'theme/app_theme.dart';
import 'inspector_accessibility/presentation/screens/permissions_screen.dart';
import 'inspector_accessibility/presentation/screens/inspector_home_screen.dart';

void main() {
  runApp(const ProviderScope(child: LocalLlmApp()));
}

class LocalLlmApp extends ConsumerStatefulWidget {
  const LocalLlmApp({super.key});

  @override
  ConsumerState<LocalLlmApp> createState() => _LocalLlmAppState();
}

class _LocalLlmAppState extends ConsumerState<LocalLlmApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelRegistryProvider.notifier).refresh();
      ref.read(llmPrefsProvider.notifier).load();
      ref.read(generationControllerProvider.notifier).attach();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Local LLM',
      theme: AppTheme.dark(),
      home: const AppHubScreen(),
      routes: {
        '/permissions': (context) => const PermissionsScreen(),
        '/inspector': (context) => const InspectorHomeScreen(),
      },
    );
  }
}
