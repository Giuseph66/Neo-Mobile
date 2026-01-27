import 'action_plan.dart';

enum ActionResult {
  success,
  failure,
  skipped,
}

class ExecutedAction {
  final PlannedAction plannedAction;
  final ActionResult result;
  final String? errorMessage;
  final DateTime executedAt;
  final Duration? executionDuration;

  ExecutedAction({
    required this.plannedAction,
    required this.result,
    this.errorMessage,
    DateTime? executedAt,
    this.executionDuration,
  }) : executedAt = executedAt ?? DateTime.now();

  bool get isSuccess => result == ActionResult.success;
  bool get isFailure => result == ActionResult.failure;
  bool get isSkipped => result == ActionResult.skipped;

  Map<String, dynamic> toJson() {
    return {
      'plannedAction': plannedAction.toJson(),
      'result': result.toString().split('.').last,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'executedAt': executedAt.toIso8601String(),
      if (executionDuration != null)
        'executionDuration': executionDuration!.inMilliseconds,
    };
  }
}



