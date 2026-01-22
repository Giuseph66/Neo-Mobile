import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gesture_models.dart';
import 'gesture_recorder.dart';
import 'key_combos.dart';
import 'shortcut_controller.dart';

class WorkflowEditorScreen extends StatefulWidget {
  const WorkflowEditorScreen({
    super.key,
    required this.controller,
    this.workflow,
  });

  final ShortcutController controller;
  final ShortcutWorkflow? workflow;

  @override
  State<WorkflowEditorScreen> createState() => _WorkflowEditorScreenState();
}

class _WorkflowEditorScreenState extends State<WorkflowEditorScreen> {
  late final TextEditingController _nameController;
  late String _comboId;
  late List<GestureAction> _actions;

  bool get _isNew => widget.workflow == null;

  @override
  void initState() {
    super.initState();
    final workflow = widget.workflow;
    _nameController = TextEditingController(
      text: workflow?.name ?? 'Novo workflow',
    );
    _comboId = workflow?.keyCombo ?? kKeyCombos.first.id;
    _actions = List<GestureAction>.from(workflow?.actions ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _recordAction() async {
    final action = await Navigator.of(context).push<GestureAction>(
      MaterialPageRoute(builder: (_) => const GestureRecorderScreen()),
    );
    if (action == null) {
      return;
    }
    setState(() {
      _actions.add(action);
    });
  }

  void _save() {
    final id = widget.workflow?.id ?? UniqueKey().toString();
    final workflow = ShortcutWorkflow(
      id: id,
      name: _nameController.text.trim().isEmpty
          ? 'Workflow'
          : _nameController.text.trim(),
      keyCombo: _comboId,
      actions: _actions,
    );
    widget.controller.updateWorkflow(workflow);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Novo workflow' : 'Editar workflow'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Salvar'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do workflow',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _comboId,
              items: [
                ...kKeyCombos.map(
                  (combo) => DropdownMenuItem(
                    value: combo.id,
                    child: Text(combo.label),
                  ),
                ),
                if (_comboId.startsWith(kCustomComboPrefix))
                  DropdownMenuItem(
                    value: _comboId,
                    child: Text('Personalizado (${comboLabelFor(_comboId)})'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _comboId = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Atalho de teclado',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final keys = await showDialog<Set<LogicalKeyboardKey>>(
                    context: context,
                    builder: (_) => const _KeyCaptureDialog(),
                  );
                  if (keys == null || keys.isEmpty) {
                    return;
                  }
                  setState(() {
                    _comboId = encodeCustomCombo(keys);
                  });
                },
                icon: const Icon(Icons.keyboard),
                label: const Text('Capturar atalho'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _actions.isEmpty
                  ? const Center(
                      child: Text('Nenhuma acao gravada.'),
                    )
                  : ListView.separated(
                      itemCount: _actions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final action = _actions[index];
                        return _ActionTile(
                          action: action,
                          onRemove: () {
                            setState(() {
                              _actions.removeAt(index);
                            });
                          },
                          onUpdate: () => setState(() {}),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _recordAction,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Gravar acao'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.onRemove,
    required this.onUpdate,
  });

  final GestureAction action;
  final VoidCallback onRemove;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _label(action),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_positionLabel(action)),
            if (action.kind == GestureKind.longPress)
              _DurationSlider(
                label: 'Duracao do pressionar (ms)',
                value: action.holdDurationMs.toDouble(),
                min: 300,
                max: 2000,
                onChanged: (value) {
                  action.holdDurationMs = value.toInt();
                  onUpdate();
                },
              ),
            if (action.kind == GestureKind.drag)
              _DurationSlider(
                label: 'Duracao do arraste (ms)',
                value: action.dragDurationMs.toDouble(),
                min: 200,
                max: 2000,
                onChanged: (value) {
                  action.dragDurationMs = max(200, value.toInt());
                  onUpdate();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _label(GestureAction action) {
    switch (action.kind) {
      case GestureKind.tap:
        return 'Tap';
      case GestureKind.longPress:
        return 'Pressionar e segurar';
      case GestureKind.drag:
        return 'Arrastar';
    }
  }

  String _positionLabel(GestureAction action) {
    final start = action.position;
    final startText =
        'Inicio: ${start.dx.toStringAsFixed(0)}, ${start.dy.toStringAsFixed(0)}';
    if (action.kind != GestureKind.drag) {
      return startText;
    }
    final end = action.end ?? start;
    return '$startText | Fim: ${end.dx.toStringAsFixed(0)}, ${end.dy.toStringAsFixed(0)}';
  }
}

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 100).round(),
          label: value.toStringAsFixed(0),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _KeyCaptureDialog extends StatefulWidget {
  const _KeyCaptureDialog();

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _keys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) {
      return;
    }
    final pressed = <LogicalKeyboardKey>{};
    if (event.isControlPressed) {
      pressed.add(LogicalKeyboardKey.control);
    }
    if (event.isAltPressed) {
      pressed.add(LogicalKeyboardKey.alt);
    }
    if (event.isShiftPressed) {
      pressed.add(LogicalKeyboardKey.shift);
    }
    if (event.isMetaPressed) {
      pressed.add(LogicalKeyboardKey.meta);
    }
    pressed.add(event.logicalKey);
    setState(() {
      _keys
        ..clear()
        ..addAll(pressed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _keys.isEmpty
        ? 'Pressione o atalho agora'
        : comboLabelFor(encodeCustomCombo(_keys));
    return AlertDialog(
      title: const Text('Capturar atalho'),
      content: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKey,
        child: SizedBox(
          width: double.infinity,
          child: Text(label),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _keys.isEmpty
              ? null
              : () => Navigator.of(context).pop(_keys),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
