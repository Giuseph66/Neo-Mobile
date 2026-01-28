import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../database/automation_database.dart';
import '../../theme/app_colors.dart';
import 'package:flutter/services.dart';

class TriggerEditScreen extends StatefulWidget {
  final int routineId;
  final AutomationTrigger? trigger;

  const TriggerEditScreen({super.key, required this.routineId, this.trigger});

  @override
  State<TriggerEditScreen> createState() => _TriggerEditScreenState();
}

class _TriggerEditScreenState extends State<TriggerEditScreen> {
  static const _platform = MethodChannel('inspector/actions');
  late AutomationTriggerType _type;
  late TimeOfDay _time;
  late List<int> _daysOfWeek;
  
  @override
  void initState() {
    super.initState();
    _type = widget.trigger?.type ?? AutomationTriggerType.daily;
    _time = TimeOfDay.now(); // TODO: Parse from trigger.timeOfDay
    _daysOfWeek = widget.trigger?.daysOfWeek ?? [1, 2, 3, 4, 5];
  }

  Future<void> _save() async {
    final trigger = AutomationTrigger(
      id: widget.trigger?.id,
      routineId: widget.routineId,
      type: _type,
      timeOfDay: '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
      daysOfWeek: _type == AutomationTriggerType.weekly ? _daysOfWeek : null,
      constraints: {},
    );

    // TODO: In a real app, update vs insert
    await AutomationDatabase.instance.addTrigger(trigger);

    // Agendar no sistema nativo
    if (_type == AutomationTriggerType.daily || _type == AutomationTriggerType.once) {
      try {
        await _platform.invokeMethod('scheduleRoutine', {
          'routineId': widget.routineId,
          'hour': _time.hour,
          'minute': _time.minute,
          'routineName': 'Rotina Agendada', // Poderia buscar o nome da rotina no DB
        });
      } catch (e) {
        debugPrint('Erro ao agendar nativamente: $e');
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tipo de Disparo', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<AutomationTriggerType>(
            value: _type,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: AutomationTriggerType.values.map((t) => DropdownMenuItem(
              value: t,
              child: Text(_getTriggerLabel(t).toUpperCase()),
            )).toList(),
            onChanged: (val) => setState(() => _type = val!),
          ),
          const SizedBox(height: 24),
          const Text('Horário', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            tileColor: AppColors.surface1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(_time.format(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
          ),
          if (_type == AutomationTriggerType.weekly) ...[
            const SizedBox(height: 24),
            const Text('Dias da Semana', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                final isSelected = _daysOfWeek.contains(dayNum);
                return FilterChip(
                  label: Text(_getDayName(dayNum)),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _daysOfWeek.add(dayNum);
                      } else {
                        _daysOfWeek.remove(dayNum);
                      }
                    });
                  },
                );
              }),
            ),
          ],
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text('Salvar Agendamento'),
          ),
        ],
      ),
    );
  }

  String _getTriggerLabel(AutomationTriggerType type) {
    switch (type) {
      case AutomationTriggerType.daily: return 'Diário';
      case AutomationTriggerType.weekly: return 'Semanal';
      case AutomationTriggerType.interval: return 'Intervalo';
      case AutomationTriggerType.once: return 'Uma vez';
    }
  }

  String _getDayName(int day) {
    switch (day) {
      case 1: return 'S';
      case 2: return 'T';
      case 3: return 'Q';
      case 4: return 'Q';
      case 5: return 'S';
      case 6: return 'S';
      case 7: return 'D';
      default: return '';
    }
  }
}
