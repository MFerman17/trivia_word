import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import 'game_3d.dart';
import 'game_icon.dart';

// =====================================================================
// EFECTOS DE VICTORIA
// Piezas que se combinan en los diálogos de "¡Victoria!" (nivel y pelea):
//   - VictoryStars: las estrellas aparecen de una en una, con sonido.
//   - CountUpChip:  el premio cuenta desde 0 hasta su valor.
//   - ConfettiLayer: confeti que cae sobre toda la pantalla.
//   - showVictoryDialog: abre el diálogo con confeti detrás y una entrada
//     con rebote, para que todos los "¡Victoria!" se sientan iguales.
// =====================================================================

/// Tiempo entre una estrella y la siguiente.
const Duration kStarGap = Duration(milliseconds: 420);

/// Cuándo aparece la primera estrella (tras la entrada del diálogo).
const Duration kFirstStarDelay = Duration(milliseconds: 450);

/// Cuánto tarda en aparecer todo: los contadores empiezan después de las
/// estrellas para que la vista vaya de una cosa a otra.
Duration victoryCountersDelay(int stars) =>
    kFirstStarDelay + kStarGap * math.max(stars, 1) + const Duration(milliseconds: 150);

/// Abre un diálogo de victoria: fondo oscuro, confeti cayendo por toda la
/// pantalla y el panel entrando con un pequeño rebote.
Future<T?> showVictoryDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool confetti = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'victory',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, _, _) => Stack(
      children: [
        if (confetti) const Positioned.fill(child: IgnorePointer(child: ConfettiLayer())),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              type: MaterialType.transparency,
              child: builder(dialogContext),
            ),
          ),
        ),
      ],
    ),
    transitionBuilder: (context, animation, _, child) {
      final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(scale), child: child),
      );
    },
  );
}

// ---------------------------------------------------------------------
// ESTRELLAS DE UNA EN UNA
// ---------------------------------------------------------------------
class VictoryStars extends StatefulWidget {
  const VictoryStars({super.key, required this.earned, this.total = 3, this.size = 46});

  final int earned;
  final int total;
  final double size;

  @override
  State<VictoryStars> createState() => _VictoryStarsState();
}

class _VictoryStarsState extends State<VictoryStars> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final Set<int> _played = {};

  Duration get _total => kFirstStarDelay + kStarGap * widget.total + const Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total)
      ..addListener(_playSounds)
      ..forward();
  }

  /// Suena una campanilla en el momento en que aparece cada estrella ganada.
  void _playSounds() {
    for (var i = 0; i < widget.earned; i++) {
      if (!_played.contains(i) && _elapsed >= _startOf(i)) {
        _played.add(i);
        AudioService.playStar();
      }
    }
  }

  Duration get _elapsed => _total * _c.value;
  Duration _startOf(int i) => kFirstStarDelay + kStarGap * i;

  /// Progreso 0..1 de la estrella i (cada una tarda 550 ms en asentarse).
  double _progress(int i) {
    final ms = (_elapsed - _startOf(i)).inMilliseconds / 550;
    return ms.clamp(0.0, 1.0);
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
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.total; i++) _star(i),
        ],
      ),
    );
  }

  Widget _star(int i) {
    final won = i < widget.earned;
    final p = _progress(i);
    // La del centro un poco más grande y más alta, como un podio.
    final middle = widget.total == 3 && i == 1;
    final size = widget.size * (middle ? 1.2 : 1.0);
    final scale = won ? Curves.elasticOut.transform(p) : Curves.easeOut.transform(p);
    final turn = won ? (1 - Curves.easeOut.transform(p)) * -0.6 : 0.0;
    final glow = won && p > 0.3;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 4, middle ? 10 : 0),
      child: SizedBox(
        width: size * 1.25,
        height: size * 1.25,
        child: Transform.rotate(
          angle: turn,
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: glow
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: WM.gold.withValues(alpha: 0.55), blurRadius: 18)],
                    )
                  : null,
              alignment: Alignment.center,
              child: won
                  ? GameIcon('⭐', size: size)
                  : Icon(Icons.star_rounded, size: size * 1.15, color: Colors.white24),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// PREMIO QUE CUENTA HACIA ARRIBA
// ---------------------------------------------------------------------
class CountUpChip extends StatefulWidget {
  const CountUpChip({
    super.key,
    required this.emoji,
    required this.value,
    this.suffix = '',
    this.accent = WM.gold,
    this.delay = Duration.zero,
    this.sound = false,
  });

  final String emoji;
  final int value;
  final String suffix;
  final Color accent;
  final Duration delay;

  /// Suena el tintineo de monedas al empezar a contar.
  final bool sound;

  @override
  State<CountUpChip> createState() => _CountUpChipState();
}

class _CountUpChipState extends State<CountUpChip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // Más premio, un poco más de tiempo contando (entre 0,6 y 1,4 s).
    duration: Duration(milliseconds: (600 + widget.value * 4).clamp(600, 1400).toInt()),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      if (widget.sound && widget.value > 0) AudioService.playCoins();
      _c.forward();
    });
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
      builder: (context, _) {
        final v = (widget.value * Curves.easeOutCubic.transform(_c.value)).round();
        // Al terminar, un pequeño "latido" para que se note que ya está.
        final pop = _c.isCompleted ? 1.0 : 1.0 + 0.08 * math.sin(_c.value * math.pi);
        return Transform.scale(
          scale: pop,
          child: Chip3D(emoji: widget.emoji, text: '+$v${widget.suffix}', accent: widget.accent),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// CONFETI
// ---------------------------------------------------------------------
class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({super.key, this.pieces = 90, this.duration = const Duration(milliseconds: 3200)});

  final int pieces;
  final Duration duration;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Piece> _pieces;

  static const _colors = [WM.gold, WM.cyan, Color(0xFFFF5EA8), WM.violet, Color(0xFF7CFF6B), Colors.white];

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _pieces = List.generate(widget.pieces, (_) {
      return _Piece(
        x: r.nextDouble(),
        // Empiezan a distintas alturas por encima de la pantalla.
        delay: r.nextDouble() * 0.35,
        speed: 0.75 + r.nextDouble() * 0.6,
        drift: (r.nextDouble() - 0.5) * 0.25,
        sway: 0.02 + r.nextDouble() * 0.04,
        spin: (r.nextDouble() - 0.5) * 14,
        w: 6 + r.nextDouble() * 6,
        h: 9 + r.nextDouble() * 8,
        color: _colors[r.nextInt(_colors.length)],
      );
    });
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
      builder: (context, _) => _c.isCompleted
          ? const SizedBox.shrink()
          : CustomPaint(painter: _ConfettiPainter(_pieces, _c.value), size: Size.infinite),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.sway,
    required this.spin,
    required this.w,
    required this.h,
    required this.color,
  });

  final double x, delay, speed, drift, sway, spin, w, h;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 60);
      final x = (p.x + p.drift * local + math.sin(local * 12 + p.x * 9) * p.sway) * size.width;
      // Se apaga en el último 25 % del recorrido.
      final fade = local > 0.75 ? (1 - local) / 0.25 : 1.0;
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      // El "volteo" del papel: el ancho visible cambia como si girara.
      final flip = math.cos(local * p.spin * 1.7).abs() * 0.8 + 0.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.w * flip, height: p.h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
