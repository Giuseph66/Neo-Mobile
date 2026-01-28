import 'package:flutter/material.dart';
import '../widgets/run_status_chip.dart';
import '../../widgets/empty_state_widget.dart';

class RunsHistoryScreen extends StatelessWidget {
  const RunsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Execuções')),
      body: const EmptyStateWidget(
        title: 'Nenhuma execução',
        description: 'As execuções das suas rotinas aparecerão aqui.',
        icon: Icons.history,
      ),
    );
  }
}
