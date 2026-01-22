import 'dart:async';

import 'package:flutter/material.dart';

import '../inspector/inspector_controller.dart';
import '../inspector/inspector_demo_screen.dart';
import '../inspector/inspector_overlay.dart';
import '../overlay_control/overlay_controller.dart';
import '../overlay_control/overlay_status.dart';
import '../theme/app_colors.dart';
import '../inspector_accessibility/presentation/screens/inspector_home_screen.dart';

class OverlayInspectorScreen extends StatefulWidget {
  const OverlayInspectorScreen({super.key});

  @override
  State<OverlayInspectorScreen> createState() => _OverlayInspectorScreenState();
}

class _OverlayInspectorScreenState extends State<OverlayInspectorScreen>
    with WidgetsBindingObserver {
  final InspectorController _inspectorController = InspectorController();
  final OverlayController _overlayController = OverlayController();

  OverlayStatus _status = const OverlayStatus(
    hasPermission: false,
    serviceRunning: false,
  );
  StreamSubscription<String>? _eventSub;
  bool _pendingStartOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
    _eventSub = _overlayController.events.listen(_handleEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSub?.cancel();
    _inspectorController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingStartOverlay) {
      _pendingStartOverlay = false;
      _tryStartOverlayAfterPermission();
    }
  }

  Future<void> _refreshStatus() async {
    final hasPermission = await _overlayController.checkPermission();
    setState(() {
      _status = _status.copyWith(hasPermission: hasPermission);
    });
  }

  Future<void> _handleEvent(String event) async {
    switch (event) {
      case 'service_started':
        setState(() {
          _status = _status.copyWith(serviceRunning: true);
        });
        break;
      case 'service_stopped':
        setState(() {
          _status = _status.copyWith(serviceRunning: false);
        });
        break;
      case 'activate_inspector':
        // Navegar para a tela do Accessibility Inspector (funciona com apps terceiros)
        // com autoStart para iniciar automaticamente
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const InspectorHomeScreen(autoStart: true),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  Future<void> _activateOverlay() async {
    final hasPermission = await _overlayController.checkPermission();
    if (!hasPermission) {
      _pendingStartOverlay = true;
      await _overlayController.requestPermission();
      if (!mounted) {
        return;
      }
      _showSnack('Conceda permissao de overlay e volte ao app.');
      return;
    }

    final started = await _overlayController.startOverlayService();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _status.copyWith(serviceRunning: started, hasPermission: true);
    });
    _showSnack(started ? 'Overlay iniciado.' : 'Falha ao iniciar overlay.');
  }

  Future<void> _tryStartOverlayAfterPermission() async {
    final hasPermission = await _overlayController.checkPermission();
    if (!hasPermission) {
      if (!mounted) {
        return;
      }
      _showSnack('Permissao de overlay negada.');
      return;
    }
    final started = await _overlayController.startOverlayService();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _status.copyWith(serviceRunning: started, hasPermission: true);
    });
    if (started) {
      _showSnack('Overlay iniciado.');
    }
  }

  Future<void> _deactivateOverlay() async {
    final stopped = await _overlayController.stopOverlayService();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _status.copyWith(serviceRunning: !stopped);
    });
    _showSnack(stopped ? 'Overlay finalizado.' : 'Falha ao finalizar overlay.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InspectorOverlayManager(
      controller: _inspectorController,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Overlay + Inspector'),
        ),
        body: Column(
          children: [
            _buildControls(context),
            const Divider(height: 1),
            const Expanded(child: InspectorDemoScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _activateOverlay,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ativar Overlay'),
              ),
              OutlinedButton.icon(
                onPressed: _deactivateOverlay,
                icon: const Icon(Icons.close),
                label: const Text('Desativar Overlay'),
              ),
              ElevatedButton.icon(
                onPressed: () => _inspectorController.setEnabled(true),
                icon: const Icon(Icons.search),
                label: const Text('Ativar Inspector Mode'),
              ),
              OutlinedButton.icon(
                onPressed: () => _inspectorController.setEnabled(false),
                icon: const Icon(Icons.hide_source),
                label: const Text('Desativar Inspector Mode'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusChip(
                label: _status.hasPermission
                    ? 'Permissao OK'
                    : 'Sem permissao',
                color: _status.hasPermission
                    ? AppColors.success
                    : AppColors.danger,
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: _status.serviceRunning
                    ? 'Overlay ativo'
                    : 'Overlay parado',
                color: _status.serviceRunning
                    ? AppColors.primary
                    : AppColors.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
