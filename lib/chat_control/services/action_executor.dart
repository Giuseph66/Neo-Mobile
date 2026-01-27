import 'dart:async';

import '../../inspector_accessibility/data/inspector_repository.dart';
import '../../inspector_accessibility/domain/models/ui_snapshot.dart';
import '../models/action_plan.dart';
import '../models/executed_action.dart';
import 'element_matcher.dart';

class ActionExecutor {
  final InspectorRepository _repository;

  ActionExecutor(this._repository);

  /// Executa uma ação planejada
  /// Retorna o resultado da execução
  Future<ExecutedAction> execute(
    PlannedAction action,
    UiSnapshot currentSnapshot,
  ) async {
    final startTime = DateTime.now();

    try {
      switch (action.type) {
        case ActionType.click:
          return await _executeClick(action, currentSnapshot, startTime);
        case ActionType.scrollForward:
          return await _executeScrollForward(action, currentSnapshot, startTime);
        case ActionType.scrollBackward:
          return await _executeScrollBackward(action, currentSnapshot, startTime);
        case ActionType.tap:
          return await _executeTap(action, currentSnapshot, startTime);
        case ActionType.swipe:
          return await _executeSwipe(action, currentSnapshot, startTime);
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: e.toString(),
        executionDuration: duration,
      );
    }
  }

  /// Executa um clique em um elemento
  Future<ExecutedAction> _executeClick(
    PlannedAction action,
    UiSnapshot snapshot,
    DateTime startTime,
  ) async {
    if (action.target == null || action.target!.isEmpty) {
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: 'Target não especificado para clique',
        executionDuration: DateTime.now().difference(startTime),
      );
    }

    // Encontrar elemento por texto
    final match = ElementMatcher.findBestMatch(snapshot, action.target!);
    if (match == null) {
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: 'Elemento "${action.target}" não encontrado na tela',
        executionDuration: DateTime.now().difference(startTime),
      );
    }

    final node = match.node;
    if (!node.clickable) {
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: 'Elemento "${action.target}" não é clicável',
        executionDuration: DateTime.now().difference(startTime),
      );
    }

    // Selecionar e clicar
    try {
      await _repository.selectNode(node.id);
      await Future.delayed(const Duration(milliseconds: 100)); // Pequeno delay
      final success = await _repository.clickSelected();

      final duration = DateTime.now().difference(startTime);
      return ExecutedAction(
        plannedAction: action,
        result: success ? ActionResult.success : ActionResult.failure,
        errorMessage: success ? null : 'Falha ao executar clique',
        executionDuration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: e.toString(),
        executionDuration: duration,
      );
    }
  }

  /// Executa scroll para frente (baixo)
  Future<ExecutedAction> _executeScrollForward(
    PlannedAction action,
    UiSnapshot snapshot,
    DateTime startTime,
  ) async {
    try {
      // Se há target, tentar encontrar elemento scrollável
      if (action.target != null && action.target!.isNotEmpty) {
        final match = ElementMatcher.findBestMatch(snapshot, action.target!);
        if (match != null && match.node.scrollable) {
          await _repository.selectNode(match.node.id);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      final success = await _repository.scrollForward();
      final duration = DateTime.now().difference(startTime);

      return ExecutedAction(
        plannedAction: action,
        result: success ? ActionResult.success : ActionResult.failure,
        errorMessage: success ? null : 'Falha ao executar scroll',
        executionDuration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: e.toString(),
        executionDuration: duration,
      );
    }
  }

  /// Executa scroll para trás (cima)
  Future<ExecutedAction> _executeScrollBackward(
    PlannedAction action,
    UiSnapshot snapshot,
    DateTime startTime,
  ) async {
    try {
      // Se há target, tentar encontrar elemento scrollável
      if (action.target != null && action.target!.isNotEmpty) {
        final match = ElementMatcher.findBestMatch(snapshot, action.target!);
        if (match != null && match.node.scrollable) {
          await _repository.selectNode(match.node.id);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      final success = await _repository.scrollBackward();
      final duration = DateTime.now().difference(startTime);

      return ExecutedAction(
        plannedAction: action,
        result: success ? ActionResult.success : ActionResult.failure,
        errorMessage: success ? null : 'Falha ao executar scroll',
        executionDuration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: e.toString(),
        executionDuration: duration,
      );
    }
  }

  /// Executa tap em coordenadas
  Future<ExecutedAction> _executeTap(
    PlannedAction action,
    UiSnapshot snapshot,
    DateTime startTime,
  ) async {
    try {
      // Coordenadas devem estar em metadata
      final metadata = action.metadata;
      if (metadata == null) {
        return ExecutedAction(
          plannedAction: action,
          result: ActionResult.failure,
          errorMessage: 'Coordenadas não especificadas para tap',
          executionDuration: DateTime.now().difference(startTime),
        );
      }

      final x = metadata['x'] as int?;
      final y = metadata['y'] as int?;
      if (x == null || y == null) {
        return ExecutedAction(
          plannedAction: action,
          result: ActionResult.failure,
          errorMessage: 'Coordenadas inválidas para tap',
          executionDuration: DateTime.now().difference(startTime),
        );
      }

      await _repository.tap(x, y);
      final duration = DateTime.now().difference(startTime);

      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.success,
        executionDuration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: e.toString(),
        executionDuration: duration,
      );
    }
  }

  /// Executa swipe
  Future<ExecutedAction> _executeSwipe(
    PlannedAction action,
    UiSnapshot snapshot,
    DateTime startTime,
  ) async {
    try {
      // Coordenadas devem estar em metadata
      final metadata = action.metadata;
      if (metadata == null) {
        return ExecutedAction(
          plannedAction: action,
          result: ActionResult.failure,
          errorMessage: 'Coordenadas não especificadas para swipe',
          executionDuration: DateTime.now().difference(startTime),
        );
      }

      final x1 = metadata['x1'] as int?;
      final y1 = metadata['y1'] as int?;
      final x2 = metadata['x2'] as int?;
      final y2 = metadata['y2'] as int?;

      if (x1 == null || y1 == null || x2 == null || y2 == null) {
        return ExecutedAction(
          plannedAction: action,
          result: ActionResult.failure,
          errorMessage: 'Coordenadas inválidas para swipe',
          executionDuration: DateTime.now().difference(startTime),
        );
      }

      await _repository.swipe(x1, y1, x2, y2);
      final duration = DateTime.now().difference(startTime);

      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.success,
        executionDuration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExecutedAction(
        plannedAction: action,
        result: ActionResult.failure,
        errorMessage: e.toString(),
        executionDuration: duration,
      );
    }
  }
}

