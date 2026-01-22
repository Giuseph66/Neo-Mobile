import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class KeyCombo {
  const KeyCombo({
    required this.id,
    required this.label,
    required this.keySet,
  });

  final String id;
  final String label;
  final LogicalKeySet keySet;
}

final List<KeyCombo> kKeyCombos = [
  KeyCombo(
    id: 'ctrl+alt+1',
    label: 'Ctrl + Alt + 1',
    keySet: LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.digit1,
    ),
  ),
  KeyCombo(
    id: 'ctrl+alt+2',
    label: 'Ctrl + Alt + 2',
    keySet: LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.digit2,
    ),
  ),
  KeyCombo(
    id: 'ctrl+alt+3',
    label: 'Ctrl + Alt + 3',
    keySet: LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.digit3,
    ),
  ),
  KeyCombo(
    id: 'ctrl+shift+1',
    label: 'Ctrl + Shift + 1',
    keySet: LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.digit1,
    ),
  ),
  KeyCombo(
    id: 'ctrl+shift+2',
    label: 'Ctrl + Shift + 2',
    keySet: LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.digit2,
    ),
  ),
  KeyCombo(
    id: 'ctrl+shift+3',
    label: 'Ctrl + Shift + 3',
    keySet: LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.digit3,
    ),
  ),
];

const String kCustomComboPrefix = 'custom:';

KeyCombo comboById(String id) {
  return kKeyCombos.firstWhere(
    (combo) => combo.id == id,
    orElse: () => kKeyCombos.first,
  );
}

LogicalKeySet? keySetForCombo(String id) {
  if (id.startsWith(kCustomComboPrefix)) {
    final raw = id.substring(kCustomComboPrefix.length);
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final keys = decoded
          .map((value) => LogicalKeyboardKey.findKeyByKeyId(value as int))
          .whereType<LogicalKeyboardKey>()
          .toList();
      if (keys.isEmpty) {
        return null;
      }
      return LogicalKeySet.fromSet(keys.toSet());
    } catch (_) {
      return null;
    }
  }
  return comboById(id).keySet;
}

String comboLabelFor(String id) {
  if (id.startsWith(kCustomComboPrefix)) {
    final raw = id.substring(kCustomComboPrefix.length);
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final labels = decoded
          .map((value) => LogicalKeyboardKey.findKeyByKeyId(value as int))
          .whereType<LogicalKeyboardKey>()
          .map(
            (key) =>
                key.keyLabel.isEmpty ? (key.debugName ?? 'Key') : key.keyLabel,
          )
          .toList();
      return labels.join(' + ');
    } catch (_) {
      return 'Personalizado';
    }
  }
  return comboById(id).label;
}

String encodeCustomCombo(Set<LogicalKeyboardKey> keys) {
  final ids = keys.map((key) => key.keyId).toList();
  return '$kCustomComboPrefix${jsonEncode(ids)}';
}
