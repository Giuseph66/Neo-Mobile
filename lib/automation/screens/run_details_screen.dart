import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../../theme/app_colors.dart';
import '../widgets/run_status_chip.dart';

class RunDetailsScreen extends StatelessWidget {
  final AutomationRun run;

  const RunDetailsScreen({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Log da Execução #${run.id}')),
      body: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(child: _buildTimeline()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Início: ${run.startedAt}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Fim: ${run.endedAt ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          RunStatusChip(status: run.status),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    // Mock steps
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Container(width: 2, color: Colors.grey.withOpacity(0.3)),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Passo ${index + 1}: Tap "Entrar"', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Duração: 842ms', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const Text('Status: Sucesso ✅', style: TextStyle(fontSize: 12, color: Colors.green)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
