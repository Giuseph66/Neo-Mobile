import 'dart:math';

import 'package:flutter/material.dart';

import 'gesture_models.dart';

class GestureRecorderScreen extends StatefulWidget {
  const GestureRecorderScreen({super.key});

  @override
  State<GestureRecorderScreen> createState() => _GestureRecorderScreenState();
}

class _GestureRecorderScreenState extends State<GestureRecorderScreen> {
  Offset? _start;
  Offset? _current;
  final Stopwatch _stopwatch = Stopwatch();
  String _hint = 'Toque, segure ou arraste na tela.';

  void _onPointerDown(PointerDownEvent event) {
    _start = event.position;
    _current = event.position;
    _stopwatch
      ..reset()
      ..start();
    setState(() {
      _hint = 'Solte para finalizar a acao.';
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_start == null) {
      return;
    }
    _current = event.position;
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_start == null) {
      return;
    }
    _stopwatch.stop();
    final start = _start!;
    final end = _current ?? event.position;
    final distance = (end - start).distance;
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final action = _buildAction(start, end, distance, elapsedMs);
    Navigator.of(context).pop(action);
  }

  GestureAction _buildAction(
    Offset start,
    Offset end,
    double distance,
    int elapsedMs,
  ) {
    const dragThreshold = 24.0;
    const longPressThreshold = 420;

    if (distance >= dragThreshold) {
      return GestureAction.drag(
        position: start,
        end: end,
        dragDurationMs: max(200, elapsedMs),
      );
    }
    if (elapsedMs >= longPressThreshold) {
      return GestureAction.longPress(
        position: start,
        holdDurationMs: elapsedMs,
      );
    }
    return GestureAction.tap(position: start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: Stack(
          children: [
            if (_start != null && _current != null)
              CustomPaint(
                painter: _GesturePathPainter(start: _start!, end: _current!),
                size: Size.infinite,
              ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    const Text(
                      'Gravando gesto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hint,
                      style: const TextStyle(color: Color(0xFFCBD5F5)),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_start != null)
              Positioned(
                left: _start!.dx - 14,
                top: _start!.dy - 14,
                child: _TouchMarker(color: const Color(0xFF22D3EE)),
              ),
            if (_current != null)
              Positioned(
                left: _current!.dx - 12,
                top: _current!.dy - 12,
                child: _TouchMarker(color: const Color(0xFF2E67FF), size: 24),
              ),
          ],
        ),
      ),
    );
  }
}

class _TouchMarker extends StatelessWidget {
  const _TouchMarker({required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.3),
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _GesturePathPainter extends CustomPainter {
  _GesturePathPainter({required this.start, required this.end});

  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E67FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _GesturePathPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}
