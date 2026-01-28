import 'package:flutter/material.dart';
import '../widgets/permission_status_card.dart';

class PermissionsHubScreen extends StatelessWidget {
  const PermissionsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações e Permissões')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionStatusCard(
            title: 'Serviço de Acessibilidade',
            description: 'Necessário para interagir com outros aplicativos e capturar elementos.',
            isEnabled: false, // TODO: Link with controller
            icon: Icons.accessibility_new,
            onAction: () {
              // TODO: Open settings
            },
          ),
          const SizedBox(height: 12),
          PermissionStatusCard(
            title: 'Notificações',
            description: 'Receba alertas sobre o status das automações em tempo real.',
            isEnabled: true,
            icon: Icons.notifications_active,
            onAction: () {},
          ),
          const SizedBox(height: 12),
          PermissionStatusCard(
            title: 'Otimização de Bateria',
            description: 'Impedir que o sistema suspenda o app durante execuções agendadas.',
            isEnabled: false,
            icon: Icons.battery_saver,
            onAction: () {},
          ),
        ],
      ),
    );
  }
}
