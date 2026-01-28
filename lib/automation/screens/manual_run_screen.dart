import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../database/automation_database.dart';
import '../../theme/app_colors.dart';
import '../widgets/run_status_chip.dart';
import '../services/automation_runner.dart';
import '../../inspector_accessibility/presentation/accessibility_inspector_controller.dart';

class ManualRunScreen extends StatefulWidget {
  final AutomationRoutine routine;

  const ManualRunScreen({super.key, required this.routine});

  @override
  State<ManualRunScreen> createState() => _ManualRunScreenState();
}

class _ManualRunScreenState extends State<ManualRunScreen> {
  bool _isRunning = false;
  int _currentStepIndex = -1;
  List<AutomationStep> _steps = [];
  final List<String> _logs = [];
  late final AutomationRunner _runner;
  final AccessibilityInspectorController _controller = AccessibilityInspectorController();

  @override
  void initState() {
    super.initState();
    _runner = AutomationRunner(_controller);
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    final steps = await AutomationDatabase.instance.getStepsForRoutine(widget.routine.id!);
    setState(() => _steps = steps);
  }

  Future<void> _start() async {
    final isEnabled = await _controller.checkAccessibilityEnabled();
    if (!isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilite o Accessibility Service primeiro!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    await _controller.start(); // Garantir que está ouvindo
    _controller.setStreamingEnabled(true); // Habilitar telemetria para o servidor

    setState(() {
      _isRunning = true;
      _currentStepIndex = -1;
      _logs.clear();
    });

    await _runner.runRoutine(
      widget.routine,
      _steps,
      onStatus: (index, msg, isError) {
        if (mounted) {
          setState(() {
            _currentStepIndex = index;
            _logs.add(msg);
            if (index == _steps.length) _isRunning = false;
            if (isError) _isRunning = false;
          });
        }
      },
    );
  }

  void _stop() {
    _runner.stop();
    setState(() {
      _isRunning = false;
      _logs.add('Execução interrompida pelo usuário. 🛑');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rodar Agora')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.surface1,
            child: Column(
              children: [
                const Text(
                  'Status da Execução',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_isRunning)
                  LinearProgressIndicator(
                    value: _steps.isEmpty ? 0 : (_currentStepIndex / _steps.length),
                    color: AppColors.primary,
                  )
                else
                  const RunStatusChip(status: AutomationRunStatus.success),
                const SizedBox(height: 12),
                Text(
                  _isRunning 
                    ? 'Passo ${_currentStepIndex + 1} de ${_steps.length}'
                    : 'Pronto para iniciar',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _logs[index],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _logs[index].contains('✅') ? Colors.green : AppColors.text2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isRunning ? _stop : _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.red : AppColors.primary,
                  foregroundColor: _isRunning ? Colors.white : Colors.black,
                ),
                child: Text(_isRunning ? 'Parar Execução' : 'Iniciar Agora'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
