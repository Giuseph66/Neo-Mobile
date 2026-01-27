import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ai/config/ai_config_store.dart';
import 'llm/generation_controller.dart';
import 'llm/llm_prefs.dart';
import 'llm/model_registry.dart';
import 'screens/app_hub_screen.dart';
import 'theme/app_theme.dart';
import 'chat_control/screens/chat_control_screen.dart';
import 'inspector_accessibility/presentation/screens/permissions_screen.dart';
import 'inspector_accessibility/presentation/screens/inspector_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
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
      ref.read(aiConfigProvider.notifier).load();
      ref.read(modelRegistryProvider.notifier).refresh();
      ref.read(llmPrefsProvider.notifier).load();
      ref.read(generationControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neo',
      theme: AppTheme.dark(),
      home: const AppHubScreen(),
      routes: {
        '/permissions': (context) => const PermissionsScreen(),
        '/inspector': (context) => const InspectorHomeScreen(),
        '/chat-control': (context) => const ChatControlScreen(),
      },
    );
  }
}
