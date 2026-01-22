class NodeSelector {
  final String? viewId;
  final String className;
  final String? path;

  NodeSelector({
    this.viewId,
    required this.className,
    this.path,
  });

  factory NodeSelector.fromJson(Map<String, dynamic> json) {
    return NodeSelector(
      viewId: json['viewId'] as String?,
      className: json['className'] as String,
      path: json['path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (viewId != null) 'viewId': viewId,
      'className': className,
      if (path != null) 'path': path,
    };
  }

  @override
  String toString() {
    final parts = <String>[];
    if (viewId != null) parts.add('viewId=$viewId');
    parts.add('class=$className');
    if (path != null) parts.add('path=$path');
    return parts.join(', ');
  }
}

