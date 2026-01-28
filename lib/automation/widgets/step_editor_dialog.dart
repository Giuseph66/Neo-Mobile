import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import 'app_selector_dialog.dart';
import 'element_selector_dialog.dart';
import '../../chat_control/models/element_record.dart';
import '../../theme/app_colors.dart';

class StepEditorDialog extends StatefulWidget {
  final AutomationStep step;

  const StepEditorDialog({super.key, required this.step});

  @override
  State<StepEditorDialog> createState() => _StepEditorDialogState();
}

class _StepEditorDialogState extends State<StepEditorDialog> {
  late Map<String, dynamic> _params;
  String? _selectorRef;
  late int _timeoutMs;

  @override
  void initState() {
    super.initState();
    _params = Map<String, dynamic>.from(widget.step.params);
    _selectorRef = widget.step.selectorRef;
    _timeoutMs = widget.step.timeoutMs;
  }

  void _save() {
    Navigator.pop(context, AutomationStep(
      routineId: widget.step.routineId,
      order: widget.step.order,
      type: widget.step.type,
      params: _params,
      selectorRef: _selectorRef,
      timeoutMs: _timeoutMs,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurar Ação',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildFields(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFields() {
    switch (widget.step.type) {
      case AutomationStepType.delay:
        return _buildNumberField('Duração (ms)', 'duration_ms', defaultValue: 1000);
      case AutomationStepType.openApp:
        return _buildAppField();
      case AutomationStepType.inputText:
        return Column(
          children: [
            _buildTextField('Texto a digitar', 'text'),
            const SizedBox(height: 12),
            _buildSelectorField(),
          ],
        );
      case AutomationStepType.tapElement:
      case AutomationStepType.waitForElement:
        return _buildSelectorField();
      case AutomationStepType.swipe:
        return _buildTextField('Direção (up/down/left/right)', 'direction');
      default:
        return const Text('Esta ação não possui configurações adicionais.');
    }
  }

  Widget _buildTextField(String label, String key) {
    return TextFormField(
      initialValue: _params[key]?.toString() ?? '',
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: (val) => _params[key] = val,
    );
  }

  Widget _buildNumberField(String label, String key, {int? defaultValue}) {
    return TextFormField(
      initialValue: (_params[key] ?? defaultValue)?.toString() ?? '',
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: TextInputType.number,
      onChanged: (val) => _params[key] = int.tryParse(val) ?? defaultValue ?? 0,
    );
  }

  Widget _buildAppField() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Aplicativo Alvo'),
      subtitle: Text(_params['package'] ?? 'Selecionar app...'),
      trailing: const Icon(Icons.search),
      onTap: () async {
        final app = await showDialog<Map<String, String>>(
          context: context,
          builder: (_) => const AppSelectorDialog(),
        );
        if (app != null) {
          setState(() {
            _params['package'] = app['package'];
            _params['name'] = app['name'];
          });
        }
      },
    );
  }

  Widget _buildSelectorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Elemento Alvo (ID, Texto ou Path)'),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _selectorRef ?? '',
          decoration: const InputDecoration(
            hintText: 'Ex: button_login ou "Entrar"',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => _selectorRef = val,
        ),
        TextButton.icon(
          onPressed: () async {
            final el = await showDialog<ElementRecord>(
              context: context,
              builder: (_) => const ElementSelectorDialog(),
            );
            if (el != null) {
              setState(() {
                _selectorRef = el.viewId ?? el.text ?? el.path;
                // Preencher parâmetros extras se necessário
                if (widget.step.type == AutomationStepType.inputText) {
                  _params['element_id'] = el.viewId;
                }
              });
            }
          },
          icon: const Icon(Icons.center_focus_strong, size: 16),
          label: const Text('Capturar da tela', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
