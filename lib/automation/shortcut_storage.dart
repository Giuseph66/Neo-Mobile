import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gesture_models.dart';

class ShortcutStorage {
  static const String _key = 'shortcut_workflows_v1';

  Future<List<ShortcutWorkflow>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => ShortcutWorkflow.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ShortcutWorkflow> workflows) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      workflows.map((workflow) => workflow.toJson()).toList(),
    );
    await prefs.setString(_key, payload);
  }
}
