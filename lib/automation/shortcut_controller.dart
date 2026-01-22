import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'gesture_models.dart';
import 'gesture_player.dart';
import 'key_combos.dart';
import 'shortcut_storage.dart';

class ShortcutController extends ChangeNotifier {
  ShortcutController({
    ShortcutStorage? storage,
    GesturePlayer? player,
  })  : _storage = storage ?? ShortcutStorage(),
        _player = player ?? GesturePlayer();

  final ShortcutStorage _storage;
  final GesturePlayer _player;
  final List<ShortcutWorkflow> _workflows = [];

  List<ShortcutWorkflow> get workflows =>
      List<ShortcutWorkflow>.unmodifiable(_workflows);

  bool get isBusy => _player.isBusy;

  Future<void> load() async {
    _workflows
      ..clear()
      ..addAll(await _storage.load());
    notifyListeners();
  }

  Future<void> save() async {
    await _storage.save(_workflows);
  }

  void addWorkflow(ShortcutWorkflow workflow) {
    _workflows.add(workflow);
    save();
    notifyListeners();
  }

  void updateWorkflow(ShortcutWorkflow workflow) {
    final index = _workflows.indexWhere((item) => item.id == workflow.id);
    if (index == -1) {
      _workflows.add(workflow);
    } else {
      _workflows[index] = workflow;
    }
    save();
    notifyListeners();
  }

  void removeWorkflow(String id) {
    _workflows.removeWhere((item) => item.id == id);
    save();
    notifyListeners();
  }

  ShortcutWorkflow? findById(String id) {
    for (final workflow in _workflows) {
      if (workflow.id == id) {
        return workflow;
      }
    }
    return null;
  }

  Map<ShortcutActivator, Intent> shortcutMap() {
    final Map<ShortcutActivator, Intent> map = {};
    for (final workflow in _workflows) {
      final keySet = keySetForCombo(workflow.keyCombo);
      if (keySet == null) {
        continue;
      }
      map[keySet] = RunWorkflowIntent(workflow.id);
    }
    return map;
  }

  Future<void> runWorkflow(String id) async {
    final workflow = findById(id);
    if (workflow == null || workflow.actions.isEmpty) {
      return;
    }
    await _player.playActions(workflow.actions);
  }
}

class RunWorkflowIntent extends Intent {
  const RunWorkflowIntent(this.workflowId);

  final String workflowId;
}
