import 'package:flutter/material.dart';

import 'inspector_controller.dart';
import 'inspector_hit_test.dart';
import 'inspector_painter.dart';
import 'inspector_panel.dart';

class InspectorOverlayManager extends StatefulWidget {
  const InspectorOverlayManager({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final InspectorController controller;

  @override
  State<InspectorOverlayManager> createState() => _InspectorOverlayManagerState();
}

class _InspectorOverlayManagerState extends State<InspectorOverlayManager> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleController); 
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlay());
  }

  @override
  void didUpdateWidget(covariant InspectorOverlayManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleController);
      widget.controller.addListener(_handleController);
      _syncOverlay();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleController);
    _removeOverlay();
    super.dispose();
  }

  void _handleController() {
    if (!mounted) {
      return;
    }
    _syncOverlay();
  }

  void _syncOverlay() {
    if (!mounted) {
      return;
    }
    if (widget.controller.enabled) {
      _ensureOverlay();
      _entry?.markNeedsBuild();
    } else {
      _removeOverlay();
    }
  }

  void _ensureOverlay() {
    if (_entry != null) {
      return;
    }
    final overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }
    _entry = OverlayEntry(
      builder: (context) {
        return InspectorOverlayWidget(controller: widget.controller);
      },
    );
    overlay.insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.controller.enabled) {
          widget.controller.refreshNodes();
        }
        return false;
      },
      child: widget.child,
    );
  }
}

class InspectorOverlayWidget extends StatelessWidget {
  const InspectorOverlayWidget({
    super.key,
    required this.controller,
  });

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.enabled) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                if (controller.showRects)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: InspectorPainter(
                        nodes: controller.nodes,
                        selected: controller.selectedNode,
                        showLabels: true,
                      ),
                    ),
                  ),
                if (controller.mode == InspectorMode.highlight)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) {
                        final node = findNodeAtOffset(
                          controller.nodes,
                          details.globalPosition,
                        );
                        controller.selectNode(node);
                      },
                    ),
                  )
                else
                  const Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: SizedBox.shrink(),
                    ),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: _InspectorBanner(),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'inspector_off',
                    onPressed: () => controller.setEnabled(false),
                    backgroundColor: const Color(0xFFE64040),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                InspectorPanel(controller: controller),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InspectorBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E67FF)),
      ),
      child: const Text(
        'INSPECTOR ATIVO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
