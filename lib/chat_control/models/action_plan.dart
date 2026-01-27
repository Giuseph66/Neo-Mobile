enum ActionType {
  click,
  scrollForward,
  scrollBackward,
  tap,
  swipe,
}

class PlannedAction {
  final ActionType type;
  final String? target; // Texto do elemento ou coordenadas
  final String description;
  final double confidence; // 0.0 a 1.0
  final Map<String, dynamic>? metadata; // Coordenadas para tap/swipe, etc.

  PlannedAction({
    required this.type,
    this.target,
    required this.description,
    required this.confidence,
    this.metadata,
  });

  factory PlannedAction.fromJson(Map<String, dynamic> json) {
    return PlannedAction(
      type: _parseActionType(json['type'] as String),
      target: json['target'] as String?,
      description: json['description'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': _actionTypeToString(type),
      if (target != null) 'target': target,
      'description': description,
      'confidence': confidence,
      if (metadata != null) 'metadata': metadata,
    };
  }

  static ActionType _parseActionType(String type) {
    switch (type.toLowerCase()) {
      case 'click':
        return ActionType.click;
      case 'scroll_forward':
      case 'scrollforward':
        return ActionType.scrollForward;
      case 'scroll_backward':
      case 'scrollbackward':
        return ActionType.scrollBackward;
      case 'tap':
        return ActionType.tap;
      case 'swipe':
        return ActionType.swipe;
      default:
        return ActionType.click;
    }
  }

  static String _actionTypeToString(ActionType type) {
    switch (type) {
      case ActionType.click:
        return 'click';
      case ActionType.scrollForward:
        return 'scroll_forward';
      case ActionType.scrollBackward:
        return 'scroll_backward';
      case ActionType.tap:
        return 'tap';
      case ActionType.swipe:
        return 'swipe';
    }
  }
}

class ActionPlan {
  final List<PlannedAction> actions;
  final DateTime createdAt;

  ActionPlan({
    required this.actions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ActionPlan.fromJson(Map<String, dynamic> json) {
    final actionsJson = json['actions'] as List<dynamic>? ?? [];
    return ActionPlan(
      actions: actionsJson
          .map((actionJson) =>
              PlannedAction.fromJson(actionJson as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actions': actions.map((action) => action.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isEmpty => actions.isEmpty;
  int get length => actions.length;
}



