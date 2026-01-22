import 'ui_node.dart';
import 'node_selector.dart';

class UiSnapshot {
  final List<UiNode> nodes;
  final int timestamp;

  UiSnapshot({
    required this.nodes,
    required this.timestamp,
  });

  factory UiSnapshot.fromJson(Map<String, dynamic> json) {
    final nodesJson = json['nodes'] as List<dynamic>;
    return UiSnapshot(
      nodes: nodesJson
          .map((nodeJson) => UiNode.fromJson(nodeJson as Map<String, dynamic>))
          .toList(),
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((node) => node.toJson()).toList(),
      'timestamp': timestamp,
    };
  }

  UiNode? findNodeById(String nodeId) {
    try {
      return nodes.firstWhere((node) => node.id == nodeId);
    } catch (e) {
      return null;
    }
  }

  UiNode? findNodeBySelector(NodeSelector selector) {
    try {
      return nodes.firstWhere((node) =>
          node.selector.className == selector.className &&
          node.selector.viewId == selector.viewId);
    } catch (e) {
      return null;
    }
  }
}

