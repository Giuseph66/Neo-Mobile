import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inspector_controller.dart';
import 'inspector_hit_test.dart';
import 'inspector_node.dart';

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    required this.controller,
  });

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.selectedNode;
        final isList = controller.mode == InspectorMode.list;
        final panelHeight = isList ? 320.0 : 220.0;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: panelHeight,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101114),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B2D33)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControls(context),
                const SizedBox(height: 12),
                Expanded(
                  child: isList
                      ? _buildList(selected)
                      : _buildDetails(context, selected),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    final mode = controller.mode;
    return Row(
      children: [
        ToggleButtons(
          isSelected: [
            mode == InspectorMode.highlight,
            mode == InspectorMode.list,
          ],
          onPressed: (index) {
            controller.setMode(
              index == 0 ? InspectorMode.highlight : InspectorMode.list,
            );
          },
          borderRadius: BorderRadius.circular(12),
          selectedColor: Colors.white,
          fillColor: const Color(0xFF2E67FF),
          color: const Color(0xFF9CA3AF),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Tap'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Lista'),
            ),
          ],
        ),
        const SizedBox(width: 12),
        DropdownButtonHideUnderline(
          child: DropdownButton<InspectorFilter>(
            value: controller.filter,
            dropdownColor: const Color(0xFF17181C),
            items: const [
              DropdownMenuItem(
                value: InspectorFilter.all,
                child: Text('Todos'),
              ),
              DropdownMenuItem(
                value: InspectorFilter.buttons,
                child: Text('Botoes'),
              ),
              DropdownMenuItem(
                value: InspectorFilter.inputs,
                child: Text('Inputs'),
              ),
              DropdownMenuItem(
                value: InspectorFilter.tappable,
                child: Text('Tappable'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.setFilter(value);
              }
            },
          ),
        ),
        const Spacer(),
        Row(
          children: [
            const Text(
              'Retangulos',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            Switch(
              value: controller.showRects,
              onChanged: (_) => controller.toggleRects(),
              activeColor: const Color(0xFF2E67FF),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context, InspectorNode? selected) {
    if (selected == null) {
      return const Center(
        child: Text(
          'Toque em um elemento para inspecionar.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }

    final rect = selected.rect;
    final details = <String>[
      'Widget: ${selected.widgetType}',
      if (selected.label != null) 'Label: ${selected.label}',
      if (selected.widgetKey != null) 'Key: ${selected.widgetKey}',
      if (selected.parentWidgetType != null)
        'Parent: ${selected.parentWidgetType}',
      'Rect: ${rect.left.toStringAsFixed(1)},'
          '${rect.top.toStringAsFixed(1)},'
          '${rect.width.toStringAsFixed(1)},'
          '${rect.height.toStringAsFixed(1)}',
      'Categoria: ${selected.category.name}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: details.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              return Text(
                details[index],
                style: const TextStyle(color: Color(0xFFE5E7EB)),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: selected.debugInfo()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Debug info copiado.')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar debug info'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF2E67FF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(InspectorNode? selected) {
    final nodes = controller.nodes;
    if (nodes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum elemento encontrado.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }

    return ListView.separated(
      itemCount: nodes.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF2B2D33)),
      itemBuilder: (context, index) {
        final node = nodes[index];
        final color = colorForCategory(node.category);
        final rect = node.rect;
        final isSelected = selected?.id == node.id;

        return ListTile(
          onTap: () => controller.selectNode(node),
          selected: isSelected,
          selectedTileColor: const Color(0xFF1E2A44),
          leading: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          title: Text(
            node.title,
            style: const TextStyle(color: Color(0xFFE5E7EB)),
          ),
          subtitle: Text(
            'Rect ${rect.left.toStringAsFixed(0)},'
            '${rect.top.toStringAsFixed(0)},'
            '${rect.width.toStringAsFixed(0)},'
            '${rect.height.toStringAsFixed(0)}',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
          trailing: Text(
            node.category.name,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        );
      },
    );
  }
}
