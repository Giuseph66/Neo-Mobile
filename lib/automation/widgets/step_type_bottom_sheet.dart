import 'package:flutter/material.dart';
import '../models/automation_models.dart';
import '../../theme/app_colors.dart';

class StepTypeBottomSheet extends StatelessWidget {
  final ValueChanged<AutomationStepType> onSelected;

  const StepTypeBottomSheet({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adicionar Passo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.5,
              children: [
                _TypeTile(
                  type: AutomationStepType.openApp,
                  label: 'Abrir App',
                  icon: Icons.launch,
                  color: Colors.blue,
                  onTap: () => _handleSelect(context, AutomationStepType.openApp),
                ),
                _TypeTile(
                  type: AutomationStepType.tapElement,
                  label: 'Clicar',
                  icon: Icons.touch_app,
                  color: Colors.green,
                  onTap: () => _handleSelect(context, AutomationStepType.tapElement),
                ),
                _TypeTile(
                  type: AutomationStepType.inputText,
                  label: 'Digitar',
                  icon: Icons.keyboard,
                  color: Colors.purple,
                  onTap: () => _handleSelect(context, AutomationStepType.inputText),
                ),
                _TypeTile(
                  type: AutomationStepType.waitForElement,
                  label: 'Aguardar',
                  icon: Icons.hourglass_empty,
                  color: Colors.orange,
                  onTap: () => _handleSelect(context, AutomationStepType.waitForElement),
                ),
                _TypeTile(
                  type: AutomationStepType.delay,
                  label: 'Esperar',
                  icon: Icons.timer_outlined,
                  color: Colors.amber,
                  onTap: () => _handleSelect(context, AutomationStepType.delay),
                ),
                _TypeTile(
                  type: AutomationStepType.swipe,
                  label: 'Deslizar',
                  icon: Icons.swipe,
                  color: Colors.teal,
                  onTap: () => _handleSelect(context, AutomationStepType.swipe),
                ),
                _TypeTile(
                  type: AutomationStepType.back,
                  label: 'Voltar',
                  icon: Icons.arrow_back,
                  color: Colors.grey,
                  onTap: () => _handleSelect(context, AutomationStepType.back),
                ),
                _TypeTile(
                  type: AutomationStepType.home,
                  label: 'Home',
                  icon: Icons.home,
                  color: Colors.grey,
                  onTap: () => _handleSelect(context, AutomationStepType.home),
                ),
                _TypeTile(
                  type: AutomationStepType.recents,
                  label: 'Recent Apps',
                  icon: Icons.history,
                  color: Colors.blueGrey,
                  onTap: () => _handleSelect(context, AutomationStepType.recents),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSelect(BuildContext context, AutomationStepType type) {
    Navigator.pop(context);
    onSelected(type);
  }
}

class _TypeTile extends StatelessWidget {
  final AutomationStepType type;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TypeTile({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
