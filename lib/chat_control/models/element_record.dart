class ElementRecord {
  final int? id;
  final int groupId;
  final String? text;
  final String path; // Caminho/seletor do elemento
  final double positionLeft;
  final double positionTop;
  final double positionRight;
  final double positionBottom;
  final String? className;
  final String? viewId;
  final bool clickable;
  final bool scrollable;
  final bool enabled;
  final DateTime createdAt;

  ElementRecord({
    this.id,
    required this.groupId,
    this.text,
    required this.path,
    required this.positionLeft,
    required this.positionTop,
    required this.positionRight,
    required this.positionBottom,
    this.className,
    this.viewId,
    this.clickable = false,
    this.scrollable = false,
    this.enabled = false,
    required this.createdAt,
  });

  factory ElementRecord.fromMap(Map<String, dynamic> map) {
    return ElementRecord(
      id: map['id'] as int?,
      groupId: map['group_id'] as int,
      text: map['text'] as String?,
      path: map['path'] as String,
      positionLeft: (map['position_left'] as num).toDouble(),
      positionTop: (map['position_top'] as num).toDouble(),
      positionRight: (map['position_right'] as num).toDouble(),
      positionBottom: (map['position_bottom'] as num).toDouble(),
      className: map['className'] as String?,
      viewId: map['view_id'] as String?,
      clickable: (map['clickable'] as int) == 1,
      scrollable: (map['scrollable'] as int) == 1,
      enabled: (map['enabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'group_id': groupId,
      'text': text,
      'path': path,
      'position_left': positionLeft,
      'position_top': positionTop,
      'position_right': positionRight,
      'position_bottom': positionBottom,
      'className': className,
      'view_id': viewId,
      'clickable': clickable ? 1 : 0,
      'scrollable': scrollable ? 1 : 0,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}



