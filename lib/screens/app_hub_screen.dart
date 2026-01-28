import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/neon_card.dart';
import '../chat_control/screens/chat_control_screen.dart';
import 'settings/app_settings_screen.dart';
import 'home_chat_screen.dart';
import 'overlay_inspector_screen.dart';
import '../automation/screens/scheduled_automation_root.dart';

import 'package:flutter/services.dart';
import '../automation/services/automation_runner.dart';
import '../inspector_accessibility/presentation/accessibility_inspector_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../automation/screens/runs_history_screen.dart';
import '../automation/database/automation_database.dart';

class AppHubScreen extends ConsumerStatefulWidget {
  const AppHubScreen({super.key});

  @override
  ConsumerState<AppHubScreen> createState() => _AppHubScreenState();
}

class _AppHubScreenState extends ConsumerState<AppHubScreen> {
  static const _platform = MethodChannel('inspector/actions');

  @override
  void initState() {
    super.initState();
    _checkLaunchIntent();
  }

  Future<void> _checkLaunchIntent() async {
    try {
      final String? initialAction = await _platform.invokeMethod('getInitialAction');
      if (initialAction == 'run_routine') {
        final int? routineId = await _platform.invokeMethod('getInitialRoutineId');
        if (routineId != null && mounted) {
          _startAutomaion(routineId);
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar intent de lançamento: $e');
    }
  }

  Future<void> _startAutomaion(int routineId) async {
    // 1. Navegar para a tela de automação (opcional, para feedback visual)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScheduledAutomationRoot()),
    );

    // 2. Buscar rotina e execução
    try {
      final routines = await AutomationDatabase.instance.getAllRoutines();
      final routine = routines.firstWhere((r) => r.id == routineId);
      final steps = await AutomationDatabase.instance.getStepsForRoutine(routineId);

      // 3. Iniciar Runner
      final controller = ref.read(accessibilityInspectorControllerProvider);
      final runner = AutomationRunner(controller);
      
      // Delay pequeno para garantir que UI carregou
      await Future.delayed(const Duration(seconds: 1));
      
      runner.runRoutine(routine, steps);
    } catch (e) {
      debugPrint('Erro ao iniciar automação via intent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neurelix Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AppSettingsScreen(),
              ),
            ),
          ),
        ],
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
          const SizedBox(height: 12),
          _HubCard(
            title: 'Chat Control',
            description:
                'IA controlando apps terceiros via comandos em português. Combina chat LLM com Inspector de acessibilidade.',
            cta: 'Abrir Chat Control',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatControlScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _HubCard(
            title: 'Automação Agendada',
            description:
                'Crie rotinas e agendamentos para automatizar tarefas em outros aplicativos.',
            cta: 'Abrir Automações',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScheduledAutomationRoot()),
            ),
          ),
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
