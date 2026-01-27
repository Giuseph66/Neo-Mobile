class ElementGroup {
  final int id;
  final DateTime createdAt;
  final String? packageName;
  final String? screenName;

  ElementGroup({
    required this.id,
    required this.createdAt,
    this.packageName,
    this.screenName,
  });

  factory ElementGroup.fromMap(Map<String, dynamic> map) {
    return ElementGroup(
      id: map['id'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      packageName: map['package_name'] as String?,
      screenName: map['screen_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.millisecondsSinceEpoch,
      'package_name': packageName,
      'screen_name': screenName,
    };
  }
}



