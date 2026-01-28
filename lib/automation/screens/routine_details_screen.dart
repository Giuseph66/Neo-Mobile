import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../database/automation_database.dart';
import '../widgets/step_card.dart';
import '../widgets/trigger_card.dart';
import '../widgets/run_status_chip.dart';
import '../widgets/permission_status_card.dart';
import '../../theme/app_colors.dart';
import 'trigger_edit_screen.dart';
import 'manual_run_screen.dart';
import '../widgets/step_editor_dialog.dart';
import '../widgets/step_type_bottom_sheet.dart';

class RoutineDetailsScreen extends StatefulWidget {
  final AutomationRoutine routine;

  const RoutineDetailsScreen({super.key, required this.routine});

  @override
  State<RoutineDetailsScreen> createState() => _RoutineDetailsScreenState();
}

class _RoutineDetailsScreenState extends State<RoutineDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AutomationStep> _steps = [];
  List<AutomationTrigger> _triggers = [];
  List<AutomationRun> _runs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      AutomationDatabase.instance.getStepsForRoutine(widget.routine.id!),
      AutomationDatabase.instance.getTriggersForRoutine(widget.routine.id!),
      AutomationDatabase.instance.getRunsForRoutine(widget.routine.id!),
    ]);

    setState(() {
      _steps = results[0] as List<AutomationStep>;
      _triggers = results[1] as List<AutomationTrigger>;
      _runs = results[2] as List<AutomationRun>;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManualRunScreen(routine: widget.routine),
              ),
            ).then((_) => _loadData()),
            tooltip: 'Testar agora',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Passos'),
            Tab(text: 'Agendamentos'),
            Tab(text: 'Execuções'),
            Tab(text: 'Diagnóstico'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStepsTab(),
                _buildTriggersTab(),
                _buildRunsTab(),
                _buildDiagnosticTab(),
              ],
            ),
    );
  }

  Widget _buildStepsTab() {
    return Scaffold(
      body: _steps.isEmpty
          ? const Center(child: Text('Nenhum passo configurado.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _steps.length,
              onReorder: _onReorderSteps,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return StepCard(
                  key: ValueKey(step.id ?? index),
                  step: step,
                  onEdit: () => _editStep(step, index),
                  onDelete: () => _deleteStep(index),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStepSheet,
        mini: true,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _onReorderSteps(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);
    });
    
    // Atualizar ordem no banco
    final orderedSteps = _steps.asMap().entries.map((e) {
      final s = e.value;
      return AutomationStep(
        id: s.id,
        routineId: s.routineId,
        order: e.key,
        type: s.type,
        params: s.params,
        selectorRef: s.selectorRef,
        timeoutMs: s.timeoutMs,
        retryCount: s.retryCount,
      );
    }).toList();
    
    await AutomationDatabase.instance.updateSteps(widget.routine.id!, orderedSteps);
  }

  Future<void> _editStep(AutomationStep step, int index) async {
    final edited = await showDialog<AutomationStep>(
      context: context,
      builder: (_) => StepEditorDialog(step: step),
    );
    if (edited != null) {
      setState(() => _steps[index] = edited);
      await AutomationDatabase.instance.updateSteps(widget.routine.id!, _steps);
    }
  }

  Future<void> _deleteStep(int index) async {
    setState(() => _steps.removeAt(index));
    await AutomationDatabase.instance.updateSteps(widget.routine.id!, _steps);
  }

  void _showAddStepSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StepTypeBottomSheet(
        onSelected: (type) async {
          final newStep = AutomationStep(
            routineId: widget.routine.id!,
            order: _steps.length,
            type: type,
            params: type == AutomationStepType.delay ? {'duration_ms': 1000} : {},
          );
          
          setState(() => _steps.add(newStep));
          await AutomationDatabase.instance.updateSteps(widget.routine.id!, _steps);
          _loadData(); // Recarregar para pegar IDs
        },
      ),
    );
  }

  Widget _buildTriggersTab() {
    return Scaffold(
      body: _triggers.isEmpty
          ? const Center(child: Text('Nenhum agendamento ativo.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _triggers.length,
              itemBuilder: (context, index) => TriggerCard(trigger: _triggers[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TriggerEditScreen(routineId: widget.routine.id!),
          ),
        ).then((_) => _loadData()),
        child: const Icon(Icons.add_alarm),
      ),
    );
  }

  Widget _buildRunsTab() {
    if (_runs.isEmpty) {
      return const Center(child: Text('Nenhuma execução registrada.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _runs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final run = _runs[index];
        return ListTile(
          title: Text('Execução #${run.id}'),
          subtitle: Text('Início: ${run.startedAt}'),
          trailing: RunStatusChip(status: run.status),
        );
      },
    );
  }

  Widget _buildDiagnosticTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PermissionStatusCard(
          title: 'Acessibilidade',
          description: 'Habilitado e pronto para uso.',
          isEnabled: true,
          icon: Icons.accessibility,
          onAction: () {},
        ),
        const SizedBox(height: 12),
        PermissionStatusCard(
          title: 'Otimização de Bateria',
          description: 'Não ignorado. Pode falhar com tela apagada.',
          isEnabled: false,
          icon: Icons.battery_alert,
          onAction: () {},
        ),
      ],
    );
  }
}
