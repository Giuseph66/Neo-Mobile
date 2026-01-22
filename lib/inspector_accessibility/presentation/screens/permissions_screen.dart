import 'package:flutter/material.dart';
import '../../data/inspector_repository_impl.dart';
import '../../../overlay_control/overlay_controller.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final _repository = InspectorRepositoryImpl();
  final _overlayController = OverlayController();
  
  bool _accessibilityEnabled = false;
  bool _overlayEnabled = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _loading = true;
    });

    final accessibility = await _repository.isAccessibilityEnabled();
    final overlay = await _overlayController.checkPermission();

    setState(() {
      _accessibilityEnabled = accessibility;
      _overlayEnabled = overlay;
      _loading = false;
    });
  }

  Future<void> _openAccessibilitySettings() async {
    await _repository.openAccessibilitySettings();
  }

  Future<void> _openOverlaySettings() async {
    await _overlayController.requestPermission();
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissões'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  _buildTransparencySection(),
                  const SizedBox(height: 24),
                  _buildActionsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status das Permissões',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusItem(
              'Acessibilidade',
              _accessibilityEnabled,
              'Necessária para inspecionar elementos de apps terceiros',
            ),
            const SizedBox(height: 12),
            _buildStatusItem(
              'Overlay',
              _overlayEnabled,
              'Necessária para desenhar bounding boxes sobre a tela',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, bool enabled, String description) {
    return Row(
      children: [
        Icon(
          enabled ? Icons.check_circle : Icons.cancel,
          color: enabled ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransparencySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transparência & Permissões',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Por que precisamos dessas permissões?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Acessibilidade: Permite detectar elementos da interface em apps terceiros para inspeção visual e testes.',
            ),
            const SizedBox(height: 4),
            const Text(
              '• Overlay: Permite desenhar retângulos sobre a tela para visualizar elementos detectados.',
            ),
            const SizedBox(height: 16),
            const Text(
              'O que o app faz:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '✓ Inspeciona elementos da UI (metadados: classe, bounds, clickable, etc.)',
            ),
            const SizedBox(height: 4),
            const Text(
              '✓ Permite executar ações de teste (clique, scroll, swipe)',
            ),
            const SizedBox(height: 16),
            const Text(
              'O que o app NÃO faz:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '✗ NÃO captura texto digitado (senhas, OTP, etc.)',
            ),
            const SizedBox(height: 4),
            const Text(
              '✗ NÃO automatiza ações em background',
            ),
            const SizedBox(height: 4),
            const Text(
              '✗ NÃO envia dados para servidores externos',
            ),
            const SizedBox(height: 16),
            const Text(
              'Como desativar:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Vá em Configurações > Acessibilidade',
            ),
            const SizedBox(height: 4),
            const Text(
              '2. Encontre "Inspector Mode" na lista',
            ),
            const SizedBox(height: 4),
            const Text(
              '3. Desative o serviço',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      children: [
        if (!_accessibilityEnabled)
          ElevatedButton.icon(
            onPressed: _openAccessibilitySettings,
            icon: const Icon(Icons.settings),
            label: const Text('Abrir Configurações de Acessibilidade'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        if (!_accessibilityEnabled) const SizedBox(height: 12),
        if (!_overlayEnabled)
          ElevatedButton.icon(
            onPressed: _openOverlaySettings,
            icon: const Icon(Icons.layers),
            label: const Text('Solicitar Permissão de Overlay'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        if (!_overlayEnabled) const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _checkPermissions,
          icon: const Icon(Icons.refresh),
          label: const Text('Verificar Novamente'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

