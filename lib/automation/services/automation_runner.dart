import 'dart:async';
import '../models/automation_models.dart';
import '../../inspector_accessibility/presentation/accessibility_inspector_controller.dart';
import '../../inspector_accessibility/domain/models/ui_node.dart';
import '../database/automation_database.dart';

typedef StepStatusCallback = void Function(int stepIndex, String message, bool isError);

class AutomationRunner {
  final AccessibilityInspectorController _controller;
  bool _isStopped = false;

  AutomationRunner(this._controller);

  void stop() => _isStopped = true;

  Future<void> runRoutine(
    AutomationRoutine routine,
    List<AutomationStep> steps, {
    StepStatusCallback? onStatus,
  }) async {
    _isStopped = false;
    
    // 1. Criar registro no banco de dados local
    final startTime = DateTime.now();
    int? runId;
    try {
      runId = await AutomationDatabase.instance.startRun(AutomationRun(
        routineId: routine.id!,
        startedAt: startTime,
        status: AutomationRunStatus.running,
      ));
    } catch (e) {
      // Ignorar erro de DB na telemetria
    }

    onStatus?.call(-1, 'Iniciando rotina: ${routine.name}', false);
    _controller.sendLog('Iniciando rotina: ${routine.name}', level: 'info');
    _controller.sendExecutionStatus('running', routineName: routine.name, currentStep: 0);

    AutomationRunStatus finalStatus = AutomationRunStatus.success;
    String? errorSummary;

    for (int i = 0; i < steps.length; i++) {
      if (_isStopped) {
        onStatus?.call(i, 'Rotina interrompida.', false);
        _controller.sendLog('Rotina "${routine.name}" interrompida.', level: 'warn');
        _controller.sendExecutionStatus('idle', routineName: routine.name);
        finalStatus = AutomationRunStatus.cancelled;
        break;
      }

      final step = steps[i];
      try {
        _controller.sendExecutionStatus('running', routineName: routine.name, currentStep: i + 1);
        await _executeStep(step, i, onStatus);
      } catch (e) {
        onStatus?.call(i, 'Erro no passo ${i + 1}: ${e.toString()}', true);
        _controller.sendLog('Erro no passo ${i + 1}: ${e.toString()}', level: 'error');
        _controller.sendExecutionStatus('error', routineName: routine.name, currentStep: i + 1);
        finalStatus = AutomationRunStatus.failed;
        errorSummary = e.toString();
        break; // Parar execução em erro
      }
    }

    if (!_isStopped && finalStatus == AutomationRunStatus.success) {
      onStatus?.call(steps.length, 'Rotina concluída com sucesso! ✅', false);
      _controller.sendLog('Rotina "${routine.name}" concluída com sucesso!', level: 'success');
      _controller.sendExecutionStatus('success', routineName: routine.name, currentStep: steps.length);
    }

    // 2. Atualizar registro no banco
    if (runId != null) {
      try {
        await AutomationDatabase.instance.updateRun(AutomationRun(
          id: runId,
          routineId: routine.id!,
          startedAt: startTime,
          endedAt: DateTime.now(),
          status: finalStatus,
          errorSummary: errorSummary,
        ));
      } catch (e) {
        // Ignorar
      }
    }
  }

  Future<void> _executeStep(AutomationStep step, int index, StepStatusCallback? onStatus) async {
    final stepLabel = _getStepLabel(step.type);
    onStatus?.call(index, 'Executando: $stepLabel', false);
    _controller.sendLog('Executando passo ${index + 1}: $stepLabel');

    switch (step.type) {
      case AutomationStepType.delay:
        final duration = step.params['duration_ms'] ?? 1000;
        await Future.delayed(Duration(milliseconds: duration));
        break;

      case AutomationStepType.home:
        await _controller.navigateHome();
        break;

      case AutomationStepType.back:
        await _controller.navigateBack();
        break;

      case AutomationStepType.recents:
        await _controller.navigateRecents();
        break;

      case AutomationStepType.openApp:
        final pkg = step.params['package'];
        if (pkg != null) {
          // TODO: Implement openApp in controller if not exists, 
          // or use a simple tap on launcher if we know the location.
          // For now, it's a placeholder for manual intervention.
          onStatus?.call(index, 'Abra manualmente o app: $pkg', false);
          await Future.delayed(const Duration(seconds: 3));
        }
        break;

      case AutomationStepType.tapElement:
        await _interactWithElement(step, (node) => _controller.tap(
          node.bounds.center.dx.toInt(),
          node.bounds.center.dy.toInt(),
        ));
        break;

      case AutomationStepType.inputText:
        final text = step.params['text'] ?? '';
        await _interactWithElement(step, (node) async {
          await _controller.selectNode(node);
          // O plugin atual já tem inputText que usa o node selecionado
          // ignore: unused_local_variable
          final success = await _controller.inputText(text);
        });
        break;

      case AutomationStepType.swipe:
        // Mock swipe coordinates (middle of screen)
        await _controller.swipe(540, 1000, 540, 500);
        break;

      case AutomationStepType.waitForElement:
        final timeout = step.timeoutMs;
        final startTime = DateTime.now();
        bool found = false;
        
        while (!found && DateTime.now().difference(startTime).inMilliseconds < timeout) {
          if (_isStopped) return;
          final node = _findNodeInLastSnapshot(step.selectorRef);
          if (node != null) {
            found = true;
          } else {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
        
        if (!found) throw Exception('Elemento "${step.selectorRef}" não encontrado (Timeout)');
        break;
    }
    
    // Pequeno delay entre passos para estabilidade
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _interactWithElement(AutomationStep step, FutureOr<void> Function(UiNode) action) async {
    final selector = step.selectorRef;
    if (selector == null || selector.isEmpty) throw Exception('Seletor não definido');

    final node = _findNodeInLastSnapshot(selector);
    if (node != null) {
      await action(node);
    } else {
      // Tentar aguardar por 2 segundos antes de falhar
      await Future.delayed(const Duration(seconds: 2));
      final retryNode = _findNodeInLastSnapshot(selector);
      if (retryNode != null) {
        await action(retryNode);
      } else {
        throw Exception('Elemento "$selector" não encontrado na tela');
      }
    }
  }

  UiNode? _findNodeInLastSnapshot(String? selector) {
    if (selector == null || selector.isEmpty) return null;
    final snapshot = _controller.lastSnapshot;
    if (snapshot == null) return null;

    final query = selector.toLowerCase();

    // 1. Tentar busca exata primeiro (ID, Resource, Texto)
    for (final node in snapshot.nodes) {
      if (node.id == selector || node.viewIdResourceName == selector || node.text == selector) {
        return node;
      }
    }

    // 2. Tentar busca case-insensitive (Texto e Resource)
    for (final node in snapshot.nodes) {
      if (node.text?.toLowerCase() == query || node.viewIdResourceName?.toLowerCase() == query) {
        return node;
      }
    }

    // 3. Tentar busca parcial (Contém)
    for (final node in snapshot.nodes) {
      final text = node.text?.toLowerCase() ?? '';
      final res = node.viewIdResourceName?.toLowerCase() ?? '';
      if (text.contains(query) || res.contains(query)) {
        return node;
      }
    }

    return null;
  }

  String _getStepLabel(AutomationStepType type) {
    switch (type) {
      case AutomationStepType.openApp: return 'Abrir App';
      case AutomationStepType.tapElement: return 'Clicar Elemento';
      case AutomationStepType.inputText: return 'Digitar Texto';
      case AutomationStepType.waitForElement: return 'Aguardar';
      case AutomationStepType.delay: return 'Esperar';
      case AutomationStepType.back: return 'Voltar';
      case AutomationStepType.home: return 'Home';
      case AutomationStepType.swipe: return 'Deslizar';
      case AutomationStepType.recents: return 'Recentes';
    }
  }
}
