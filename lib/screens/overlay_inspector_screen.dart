import 'dart:async';

import 'package:flutter/material.dart';

import '../inspector/inspector_controller.dart';
import '../inspector/inspector_overlay.dart';
import '../overlay_control/overlay_controller.dart';
import '../overlay_control/overlay_status.dart';
import '../theme/app_colors.dart';
import '../inspector_accessibility/presentation/accessibility_inspector_controller.dart';
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
  final AccessibilityInspectorController _accessibilityController = AccessibilityInspectorController();

  OverlayStatus _status = const OverlayStatus(
    hasPermission: false,
    serviceRunning: false,
  );
  bool _accessibilityEnabled = false;
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
    _accessibilityController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pendingStartOverlay) {
        _pendingStartOverlay = false;
        _tryStartOverlayAfterPermission();
      }
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final hasPermission = await _overlayController.checkPermission();
    final isAccessibilityEnabled = await _accessibilityController.checkAccessibilityEnabled();
    setState(() {
      _status = _status.copyWith(hasPermission: hasPermission);
      _accessibilityEnabled = isAccessibilityEnabled;
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
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _refreshStatus();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Atualizar Status'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPermissionCard(),
        const SizedBox(height: 16),
        _buildServiceCard(),
      ],
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permissões e Acessibilidade',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _PermissionItem(
              title: 'Sobreposição de Tela',
              subtitle: 'Necessário para desenhar o overlay',
              enabled: _status.hasPermission,
              onTap: () => _overlayController.requestPermission(),
            ),
            const Divider(height: 24),
            _PermissionItem(
              title: 'Acessibilidade',
              subtitle: 'Necessário para apps de terceiros',
              enabled: _accessibilityEnabled,
              onTap: () {
                Navigator.of(context).pushNamed('/permissions');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controle de Serviços',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ServiceButton(
                    label: _status.serviceRunning ? 'Parar Overlay' : 'Iniciar Overlay',
                    icon: _status.serviceRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                    isActive: _status.serviceRunning,
                    onPressed: _status.serviceRunning ? _deactivateOverlay : _activateOverlay,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ServiceButton(
                    label: 'Navegar para o Inspector',
                    icon: Icons.search,
                    isActive: _accessibilityEnabled,
                    onPressed: () {
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InspectorHomeScreen(autoStart: true),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    // This is now replaced by _buildBody but kept for compatibility or reference if needed
    return Container();
  }
}

class _PermissionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _PermissionItem({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (enabled ? AppColors.success : AppColors.danger).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                enabled ? Icons.check_circle : Icons.error_outline,
                color: enabled ? AppColors.success : AppColors.danger,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  const _ServiceButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : Colors.grey[400]!;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color.withOpacity(0.1) : Colors.transparent,
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
