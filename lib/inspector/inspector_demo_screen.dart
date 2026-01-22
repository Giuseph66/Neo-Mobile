import 'package:flutter/material.dart';

import 'inspectable.dart';
import 'inspector_node.dart';

class InspectorDemoScreen extends StatelessWidget {
  const InspectorDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Demo Screen',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Inspectable(
              label: 'Primary Button',
              category: InspectableCategory.button,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Salvar'),
              ),
            ),
            Inspectable(
              label: 'Secondary Button',
              category: InspectableCategory.button,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Cancelar'),
              ),
            ),
            Inspectable(
              label: 'Text Button',
              category: InspectableCategory.button,
              child: TextButton(
                onPressed: () {},
                child: const Text('Editar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Inspectable(
          label: 'Search Field',
          category: InspectableCategory.input,
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar...',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Inspectable(
                label: 'Email Input',
                category: InspectableCategory.input,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Inspectable(
                label: 'Password Input',
                category: InspectableCategory.input,
                child: TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Inspectable(
          label: 'Card Highlight',
          category: InspectableCategory.card,
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Card Principal',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Resumo rapido com informacoes importantes.'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Inspectable(
          label: 'Tappable Tile',
          category: InspectableCategory.tappable,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  CircleAvatar(child: Icon(Icons.person)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Abrir perfil do usuario'),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Lista de Itens',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ListView.separated(
            itemCount: 6,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return Inspectable(
                label: 'Item $index',
                category: InspectableCategory.listItem,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('Item da lista #${index + 1}'),
                  subtitle: const Text('Detalhes secundarios.'),
                  trailing: const Icon(Icons.more_vert),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Inspectable(
                label: 'Switch',
                category: InspectableCategory.tappable,
                child: SwitchListTile(
                  title: const Text('Notificacoes'),
                  value: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
