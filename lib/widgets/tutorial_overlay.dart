import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import 'game_3d.dart';
import 'game_icon.dart';

/// Un paso del tutorial: qué se ilumina y qué se explica.
class TutorialStep {
  const TutorialStep({required this.target, required this.text});

  /// Zona de la pantalla que se ilumina (null = ninguna, mensaje centrado).
  final GlobalKey? target;
  final String text;
}

/// TUTORIAL
///
/// En los 3 primeros niveles del juego, antes de la primera pregunta, la
/// pantalla se oscurece y se "ilumina" una zona cada vez (el monstruo, la
/// pregunta, las respuestas, los botones de ayuda) con un globo que explica
/// para qué sirve. Así se aprende jugando, sin un manual que nadie lee.
///
/// Cada nivel lo enseña una sola vez (se guarda en el teléfono). Se puede
/// saltar con "Saltar".
class TutorialService {
  TutorialService._();

  static String _key(int level) => 'tutorial_seen_$level';

  /// Si este nivel tiene tutorial pendiente.
  static Future<bool> pending({required int world, required int chapter, required int level}) async {
    if (world != 1 || chapter != 1 || level > 3) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_key(level)) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(level), true);
    } catch (_) {}
  }
}

/// Muestra los pasos uno tras otro encima de toda la pantalla.
Future<void> showTutorial(BuildContext context, List<TutorialStep> steps) async {
  if (steps.isEmpty) return;
  await Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => _TutorialView(steps: steps),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  ));
}

class _TutorialView extends StatefulWidget {
  const _TutorialView({required this.steps});

  final List<TutorialStep> steps;

  @override
  State<_TutorialView> createState() => _TutorialViewState();
}

class _TutorialViewState extends State<_TutorialView> {
  int _index = 0;

  bool get _last => _index == widget.steps.length - 1;

  /// Rectángulo en pantalla de la zona del paso (null si no hay o no se ve).
  Rect? _targetRect() {
    final ctx = widget.steps[_index].target?.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(6);
  }

  void _next() {
    AudioService.playButtonClick();
    if (_last) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rect = _targetRect();
    final screen = MediaQuery.sizeOf(context);
    // El globo va debajo de la zona si esta queda en la mitad de arriba, y
    // encima si queda en la de abajo, para no taparla.
    final below = rect == null || rect.center.dy < screen.height / 2;

    final bubble = Panel3D(
      accent: WM.cyan,
      glow: 0.4,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El explorador es quien explica.
              ClipOval(
                child: Image.asset(
                  'assets/images/adventurer.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GameText(
                  widget.steps[_index].text,
                  style: GoogleFonts.oswald(color: Colors.white, fontSize: 15, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Puntos de progreso.
              for (var i = 0; i < widget.steps.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index ? WM.cyan : Colors.white24,
                  ),
                ),
              const Spacer(),
              if (!_last)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.tutorialSkip, style: GoogleFonts.oswald(color: Colors.white54)),
                ),
              const SizedBox(width: 4),
              Pressable3D(
                onTap: _next,
                color: _last ? WM.gold : WM.cyan,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedGameText(
                  _last ? l.tutorialPlay : l.tutorialNext,
                  size: 15,
                  font: GameFont.oswald,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return GestureDetector(
      // Tocar en cualquier parte también avanza.
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SpotlightPainter(rect))),
          if (rect != null)
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: Pulse(
                  amount: 0.02,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: WM.cyan, width: 3),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: below ? (rect == null ? screen.height * 0.35 : rect.bottom + 12) : null,
            bottom: below ? null : screen.height - rect.top + 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey(_index), child: bubble),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oscurece toda la pantalla menos un hueco redondeado en [hole].
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final path = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      path
        ..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(18)))
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, dim);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
