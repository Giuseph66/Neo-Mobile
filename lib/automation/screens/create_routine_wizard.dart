import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../database/automation_database.dart';
import '../widgets/step_type_bottom_sheet.dart';
import '../widgets/step_card.dart';
import '../widgets/app_selector_dialog.dart';
import '../widgets/step_editor_dialog.dart';
import '../../theme/app_colors.dart';

class CreateRoutineWizard extends StatefulWidget {
  const CreateRoutineWizard({super.key});

  @override
  State<CreateRoutineWizard> createState() => _CreateRoutineWizardState();
}

class _CreateRoutineWizardState extends State<CreateRoutineWizard> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Step A: Identity
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // Step B: Target App
  String? _targetAppPackage;

  // Step C: Steps
  final List<AutomationStep> _steps = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _save() async {
    final routine = AutomationRoutine(
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      targetAppPackage: _targetAppPackage,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created = await AutomationDatabase.instance.createRoutine(routine);
    if (created.id != null) {
      // Map temporary steps to the real routine ID
      final finalSteps = _steps.asMap().entries.map((e) {
        final step = e.value;
        return AutomationStep(
          routineId: created.id!,
          order: e.key,
          type: step.type,
          params: step.params,
          selectorRef: step.selectorRef,
        );
      }).toList();
      
      await AutomationDatabase.instance.updateSteps(created.id!, finalSteps);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Rotina')),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _next,
        onStepCancel: _prev,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 3 ? 'Finalizar' : 'Próximo'),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Voltar'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Identidade'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            content: _buildStepIdentity(),
          ),
          Step(
            title: const Text('App'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
            content: _buildStepApp(),
          ),
          Step(
            title: const Text('Passos'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.editing,
            content: _buildStepMapping(),
          ),
          Step(
            title: const Text('Resumo'),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.editing : StepState.indexed,
            content: _buildStepSummary(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIdentity() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome da Rotina',
              hintText: 'Ex: Abrir Instagram e curtir',
            ),
            validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              hintText: 'O que esta rotina faz?',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStepApp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecione o aplicativo alvo:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: AppColors.surface1,
          leading: const Icon(Icons.android, color: Colors.green),
          title: Text(_targetAppPackage ?? 'Nenhum selecionado'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () async {
            final app = await showDialog<Map<String, String>>(
              context: context,
              builder: (_) => const AppSelectorDialog(),
            );
            if (app != null) {
              setState(() => _targetAppPackage = app['package']);
            }
          },
        ),
      ],
    );
  }

  Widget _buildStepMapping() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sequência de ações:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => _showAddStepSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_steps.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nenhum passo adicionado ainda.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _steps.removeAt(oldIndex);
                _steps.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final step = _steps[index];
              return StepCard(
                key: ValueKey(index),
                step: step,
                onDelete: () => setState(() => _steps.removeAt(index)),
                onEdit: () async {
                  final edited = await showDialog<AutomationStep>(
                    context: context,
                    builder: (_) => StepEditorDialog(step: step),
                  );
                  if (edited != null) {
                    setState(() => _steps[index] = edited);
                  }
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildStepSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(label: 'Nome', value: _nameController.text),
        _SummaryRow(label: 'App', value: _targetAppPackage ?? 'Não definido'),
        _SummaryRow(label: 'Passos', value: '${_steps.length}'),
        const SizedBox(height: 12),
        if (_steps.isEmpty)
          const Text('⚠️ Adicione pelo menos um passo para salvar.', style: TextStyle(color: Colors.orange)),
      ],
    );
  }

  void _showAddStepSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StepTypeBottomSheet(
        onSelected: (type) {
          setState(() {
            _steps.add(AutomationStep(
              routineId: 0,
              order: _steps.length,
              type: type,
              params: type == AutomationStepType.delay ? {'duration_ms': 1000} : {},
            ));
          });
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
