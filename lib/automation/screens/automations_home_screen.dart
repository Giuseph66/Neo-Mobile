import 'package:flutter/material.dart';
import '../widgets/routine_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../models/automation_models.dart';
import '../database/automation_database.dart';
import 'create_routine_wizard.dart';
import 'routine_details_screen.dart';
import '../widgets/confirm_delete_dialog.dart';

class AutomationsHomeScreen extends StatefulWidget {
  const AutomationsHomeScreen({super.key});

  @override
  State<AutomationsHomeScreen> createState() => _AutomationsHomeScreenState();
}

class _AutomationsHomeScreenState extends State<AutomationsHomeScreen> {
  List<AutomationRoutine> _routines = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    setState(() => _isLoading = true);
    final routines = await AutomationDatabase.instance.getAllRoutines();
    setState(() {
      _routines = routines;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredRoutines = _routines.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Rotinas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar rotinas...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredRoutines.isEmpty
              ? EmptyStateWidget(
                  title: _searchQuery.isEmpty ? 'Nenhuma rotina criada' : 'Nenhum resultado',
                  description: _searchQuery.isEmpty 
                    ? 'Toque no + para criar sua primeira automação agendada.'
                    : 'Não encontramos rotinas para "$_searchQuery".',
                  icon: Icons.bolt,
                  onAction: _searchQuery.isEmpty ? _createNewRoutine : null,
                  actionLabel: 'Nova Rotina',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRoutines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final routine = filteredRoutines[index];
                    return RoutineCard(
                      routine: routine,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoutineDetailsScreen(routine: routine),
                        ),
                      ),
                      onToggle: (val) async {
                        final updated = AutomationRoutine(
                          id: routine.id,
                          name: routine.name,
                          description: routine.description,
                          targetAppPackage: routine.targetAppPackage,
                          enabled: val,
                          createdAt: routine.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        await AutomationDatabase.instance.updateRoutine(updated);
                        _loadRoutines();
                      },
                      onPlay: () {
                        // TODO: Implement direct run
                      },
                      onDelete: () => _deleteRoutine(routine),
                      onDuplicate: () => _duplicateRoutine(routine),
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoutineDetailsScreen(routine: routine),
                        ),
                      ).then((_) => _loadRoutines()),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewRoutine,
        label: const Text('Nova Rotina'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _createNewRoutine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRoutineWizard()),
    ).then((_) => _loadRoutines());
  }

  Future<void> _deleteRoutine(AutomationRoutine routine) async {
    final confirm = await showConfirmDeleteDialog(
      context: context,
      title: 'Excluir Rotina',
      content: 'Tem certeza que deseja excluir "${routine.name}"? Esta ação não pode ser desfeita.',
    );

    if (confirm) {
      await AutomationDatabase.instance.deleteRoutine(routine.id!);
      _loadRoutines();
    }
  }

  Future<void> _duplicateRoutine(AutomationRoutine routine) async {
    await AutomationDatabase.instance.duplicateRoutine(routine.id!);
    _loadRoutines();
  }
}
