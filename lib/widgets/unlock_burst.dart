import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_3d.dart';

/// Animación de "nivel desbloqueado" en el mapa, una sola vez:
///  1. un candado aparece encima del nivel, tiembla y sale despedido,
///  2. el nivel crece con rebote desde pequeño,
///  3. un anillo de luz se expande hacia fuera y desaparece.
/// Empieza con un pequeño retraso para que dé tiempo a que el mapa se
/// centre en el nivel nuevo al volver de jugar.
class UnlockBurst extends StatefulWidget {
  const UnlockBurst({super.key, required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  State<UnlockBurst> createState() => _UnlockBurstState();
}

class _UnlockBurstState extends State<UnlockBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Parte de la animación entre [a] y [b] (0..1), para encadenar fases.
  double _phase(double a, double b) => ((_c.value - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final shakeT = _phase(0.0, 0.3); // el candado tiembla
        final flyT = _phase(0.3, 0.55); // sale despedido
        final popT = _phase(0.3, 0.8); // el nivel aparece
        final ringT = _phase(0.35, 1.0); // anillo de luz

        final lockShake = shakeT < 1 ? math.sin(shakeT * math.pi * 8) * 0.25 : 0.0;
        final nodeScale = _c.value < 0.3 ? 0.0 : Curves.elasticOut.transform(popT);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Anillo que se expande.
            if (ringT > 0 && ringT < 1)
              IgnorePointer(
                child: Container(
                  width: s * (1 + ringT * 1.4),
                  height: s * (1 + ringT * 1.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: WM.cyan.withValues(alpha: (1 - ringT) * 0.9),
                      width: 4 * (1 - ringT) + 1,
                    ),
                  ),
                ),
              ),
            Transform.scale(scale: nodeScale, child: child),
            // Candado: tiembla, salta hacia arriba girando y se desvanece.
            if (flyT < 1)
              IgnorePointer(
                child: Transform.translate(
                  offset: Offset(flyT * s * 0.35, -flyT * s * 0.9),
                  child: Transform.rotate(
                    angle: lockShake + flyT * 1.2,
                    child: Opacity(
                      opacity: 1 - flyT,
                      child: Icon(Icons.lock_rounded, color: WM.gold, size: s * 0.55),
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
