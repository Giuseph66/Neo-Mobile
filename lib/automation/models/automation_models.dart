import 'dart:convert';

enum AutomationStepType {
  openApp,
  tapElement,
  inputText,
  waitForElement,
  delay,
  back,
  home,
  swipe,
  recents,
}

enum AutomationTriggerType {
  daily,
  weekly,
  interval,
  once
}

enum AutomationRunStatus {
  running,
  success,
  failed,
  cancelled
}

class AutomationRoutine {
  final int? id;
  final String name;
  final String? description;
  final String? targetAppPackage;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  AutomationRoutine({
    this.id,
    required this.name,
    this.description,
    this.targetAppPackage,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'target_app_package': targetAppPackage,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AutomationRoutine.fromMap(Map<String, dynamic> map) {
    return AutomationRoutine(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      targetAppPackage: map['target_app_package'] as String?,
      enabled: (map['enabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

class AutomationStep {
  final int? id;
  final int routineId;
  final int order;
  final AutomationStepType type;
  final String? selectorRef; // Link to element ID or path
  final Map<String, dynamic> params;
  final int timeoutMs;
  final int retryCount;

  AutomationStep({
    this.id,
    required this.routineId,
    required this.order,
    required this.type,
    this.selectorRef,
    this.params = const {},
    this.timeoutMs = 5000,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'routine_id': routineId,
      'step_order': order,
      'type': type.name,
      'selector_ref': selectorRef,
      'params': jsonEncode(params),
      'timeout_ms': timeoutMs,
      'retry_count': retryCount,
    };
  }

  factory AutomationStep.fromMap(Map<String, dynamic> map) {
    return AutomationStep(
      id: map['id'] as int?,
      routineId: map['routine_id'] as int,
      order: map['step_order'] as int,
      type: AutomationStepType.values.byName(map['type'] as String),
      selectorRef: map['selector_ref'] as String?,
      params: jsonDecode(map['params'] as String) as Map<String, dynamic>,
      timeoutMs: map['timeout_ms'] as int,
      retryCount: map['retry_count'] as int,
    );
  }
}

class AutomationTrigger {
  final int? id;
  final int routineId;
  final bool enabled;
  final AutomationTriggerType type;
  final String? timeOfDay; // HH:mm
  final List<int>? daysOfWeek; // [1, 2, 3, 4, 5, 6, 7]
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic> constraints;

  AutomationTrigger({
    this.id,
    required this.routineId,
    this.enabled = true,
    required this.type,
    this.timeOfDay,
    this.daysOfWeek,
    this.startDate,
    this.endDate,
    this.constraints = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'routine_id': routineId,
      'enabled': enabled ? 1 : 0,
      'type': type.name,
      'time_of_day': timeOfDay,
      'days_of_week': daysOfWeek != null ? jsonEncode(daysOfWeek) : null,
      'start_date': startDate?.millisecondsSinceEpoch,
      'end_date': endDate?.millisecondsSinceEpoch,
      'constraints': jsonEncode(constraints),
    };
  }

  factory AutomationTrigger.fromMap(Map<String, dynamic> map) {
    return AutomationTrigger(
      id: map['id'] as int?,
      routineId: map['routine_id'] as int,
      enabled: (map['enabled'] as int) == 1,
      type: AutomationTriggerType.values.byName(map['type'] as String),
      timeOfDay: map['time_of_day'] as String?,
      daysOfWeek: map['days_of_week'] != null 
          ? (jsonDecode(map['days_of_week'] as String) as List).cast<int>() 
          : null,
      startDate: map['start_date'] != null ? DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int) : null,
      endDate: map['end_date'] != null ? DateTime.fromMillisecondsSinceEpoch(map['end_date'] as int) : null,
      constraints: jsonDecode(map['constraints'] as String) as Map<String, dynamic>,
    );
  }
}

class AutomationRun {
  final int? id;
  final int routineId;
  final int? triggerId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final AutomationRunStatus status;
  final String? errorSummary;

  AutomationRun({
    this.id,
    required this.routineId,
    this.triggerId,
    required this.startedAt,
    this.endedAt,
    this.status = AutomationRunStatus.running,
    this.errorSummary,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'routine_id': routineId,
      'trigger_id': triggerId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'status': status.name,
      'error_summary': errorSummary,
    };
  }

  factory AutomationRun.fromMap(Map<String, dynamic> map) {
    return AutomationRun(
      id: map['id'] as int?,
      routineId: map['routine_id'] as int,
      triggerId: map['trigger_id'] as int?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      endedAt: map['ended_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int) : null,
      status: AutomationRunStatus.values.byName(map['status'] as String),
      errorSummary: map['error_summary'] as String?,
    );
  }
}

class AutomationRunStepLog {
  final int runId;
  final int stepId;
  final String status;
  final DateTime startedAt;
  final DateTime endedAt;
  final String? error;
  final Map<String, dynamic> debugData;

  AutomationRunStepLog({
    required this.runId,
    required this.stepId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    this.error,
    this.debugData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'run_id': runId,
      'step_id': stepId,
      'status': status,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt.millisecondsSinceEpoch,
      'error': error,
      'debug_data': jsonEncode(debugData),
    };
  }

  factory AutomationRunStepLog.fromMap(Map<String, dynamic> map) {
    return AutomationRunStepLog(
      runId: map['run_id'] as int,
      stepId: map['step_id'] as int,
      status: map['status'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
      error: map['error'] as String?,
      debugData: jsonDecode(map['debug_data'] as String) as Map<String, dynamic>,
    );
  }
}
