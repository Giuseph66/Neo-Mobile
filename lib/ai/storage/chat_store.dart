import 'package:hive/hive.dart';

import '../models/chat_session.dart';

class ChatStore {
  ChatStore(this._box);

  static const boxName = 'chat_sessions';
  static const activeKey = 'active_session_id';

  final Box _box;

  static Future<ChatStore> open() async {
    final box = await Hive.openBox(boxName);
    return ChatStore(box);
  }

  Future<ChatSession?> loadActiveSession() async {
    final id = _box.get(activeKey) as String?;
    if (id == null) {
      return null;
    }
    return loadSession(id);
  }

  Future<void> setActiveSession(String id) async {
    await _box.put(activeKey, id);
  }

  Future<ChatSession?> loadSession(String id) async {
    final raw = _box.get(id);
    if (raw is Map) {
      return ChatSession.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> saveSession(ChatSession session) async {
    await _box.put(session.id, session.toMap());
    await setActiveSession(session.id);
  }
}
