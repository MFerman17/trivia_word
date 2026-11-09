import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hace temblar la pantalla y pinta un destello rojo en los bordes cuando
/// el jugador recibe un golpe.
///
/// [trigger] es un contador: cada vez que SUBE, la pantalla tiembla. Se usa
/// "daño recibido" (o "ataques recibidos") en lugar de la vida, para que
/// curarse con una poción (la vida sube) no haga temblar nada.
class ScreenShake extends StatefulWidget {
  const ScreenShake({
    super.key,
    required this.trigger,
    required this.child,
    this.strength = 10,
    this.delay = Duration.zero,
  });

  final int trigger;
  final Widget child;

  /// Desplazamiento máximo en píxeles.
  final double strength;

  /// Espera antes de temblar, para que coincida con el momento en que el
  /// golpe del monstruo "llega" en su animación.
  final Duration delay;

  @override
  State<ScreenShake> createState() => _ScreenShakeState();
}

class _ScreenShakeState extends State<ScreenShake> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(ScreenShake old) {
    super.didUpdateWidget(old);
    if (widget.trigger > old.trigger) {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        if (t == 0 || t == 1) return child!;
        // Sacudida que se va apagando: rápida a los lados, algo menos arriba y abajo.
        final fade = 1 - t;
        final dx = math.sin(t * math.pi * 9) * widget.strength * fade;
        final dy = math.cos(t * math.pi * 7) * widget.strength * 0.4 * fade;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Transform.translate(offset: Offset(dx, dy), child: child),
            // Viñeta roja en los bordes, que se desvanece.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [
                        Colors.transparent,
                        const Color(0xFFFF2D3D).withValues(alpha: 0.38 * fade),
                      ],
                      stops: const [0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
