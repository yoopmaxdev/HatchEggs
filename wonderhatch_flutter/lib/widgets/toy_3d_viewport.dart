import 'package:flutter/material.dart';

import '../engine3d/toy_3d_renderer.dart';
import '../models/toy_customization.dart';
import '../models/toy_series.dart';

class Toy3DViewport extends StatefulWidget {
  final ToyDefinition toy;
  final ToyCustomization customization;
  final double zoom;
  final bool autoSpin;
  final bool interactive;

  const Toy3DViewport({
    super.key,
    required this.toy,
    this.customization = const ToyCustomization(),
    this.zoom = 1.0,
    this.autoSpin = true,
    this.interactive = true,
  });

  @override
  State<Toy3DViewport> createState() => _Toy3DViewportState();
}

class _Toy3DViewportState extends State<Toy3DViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  double _rotY = 0.35;
  double _rotX = -0.15;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(() {
        if (widget.autoSpin && !_isDragging) {
          setState(() {
            _rotY += 0.012;
          });
        }
      });
    if (widget.autoSpin) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant Toy3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoSpin && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.autoSpin && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      painter: Toy3DPainter(
        toy: widget.toy,
        customization: widget.customization,
        rotY: _rotY,
        rotX: _rotX,
        zoom: widget.zoom,
      ),
      child: const SizedBox.expand(),
    );

    if (!widget.interactive) return painter;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _isDragging = true,
      onPanUpdate: (details) {
        setState(() {
          _rotY += details.delta.dx * 0.014;
          _rotX = (_rotX + details.delta.dy * 0.01).clamp(-0.65, 0.55);
        });
      },
      onPanEnd: (_) => _isDragging = false,
      onPanCancel: () => _isDragging = false,
      onDoubleTap: () {
        setState(() {
          _rotY = 0.35;
          _rotX = -0.15;
        });
      },
      child: painter,
    );
  }
}
