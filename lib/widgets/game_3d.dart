// =====================================================================
// PIEZAS 3D REUTILIZABLES — estilo "Words & Monsters"
//
// Idea general: en Flutter no hay 3D "real" sin motores externos, así que
// el volumen se FINGE con cuatro trucos que usan los juegos móviles:
//   1. Canto inferior: una capa más oscura asoma por debajo de la cara
//      (como el lateral de un bloque). Panel3D y Pressable3D.
//   2. Brillo superior: una franja blanca semitransparente arriba simula
//      la luz que viene de arriba. Bar3D, Pressable3D, Socket3D.
//   3. Contorno grueso oscuro (#0D0326) en todo, para el look "cartoon".
//   4. Perspectiva real con Matrix4 (setEntry(3, 2, …)) para las entradas
//      animadas que "caen" hacia el jugador. EntranceFlip.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta y medidas comunes del juego.
class WM {
  static const Color outline = Color(0xFF0D0326);
  static const Color cyan = Color(0xFF1EE3CF);
  static const Color cyanLight = Color(0xFFA8FFF6);
  static const Color bone = Color(0xFFF4EBDD);
  static const Color panelTop = Color(0xFF2A1A5E);
  static const Color panelBottom = Color(0xFF160E36);
  static const Color gold = Color(0xFFFFC93C);
  static const Color silver = Color(0xFFCFD8E8);
  static const Color bronze = Color(0xFFD9894E);
  static const Color green = Color(0xFF2FC22A);
  static const Color violet = Color(0xFF7C6BD6);
  static const double skew = -0.2;
}

/// Aclara (amount > 0) u oscurece (amount < 0) un color.
Color shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

enum GameFont { anton, oswald, metal }

// ---------------------------------------------------------------------
// TEXTO CON CONTORNO Y RELIEVE (el mismo truco del logo de la portada)
// Capa 1: contorno desplazado hacia abajo  -> "grosor" del texto
// Capa 2: contorno en su sitio
// Capa 3: relleno con degradado
// ---------------------------------------------------------------------
class OutlinedGameText extends StatelessWidget {
  const OutlinedGameText(
    this.text, {
    super.key,
    this.size = 20,
    this.font = GameFont.anton,
    this.colors = const [Colors.white, WM.bone],
    this.letterSpacing = 1,
  });

  final String text;
  final double size;
  final GameFont font;
  final List<Color> colors;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = switch (font) {
      GameFont.anton =>
        GoogleFonts.anton(fontSize: size, letterSpacing: letterSpacing, height: 1.15),
      GameFont.oswald => GoogleFonts.oswald(
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: letterSpacing,
          height: 1.15),
      GameFont.metal =>
        GoogleFonts.metalMania(fontSize: size, letterSpacing: letterSpacing, height: 1.1),
    };
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.16
      ..strokeJoin = StrokeJoin.round
      ..color = WM.outline;

    Text layer(TextStyle style) => Text(
          text,
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, size * 0.09),
          child: layer(base.copyWith(foreground: stroke)),
        ),
        layer(base.copyWith(foreground: stroke)),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(bounds),
          child: layer(base.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// FONDO: la misma imagen de paisaje de la app, oscurecida, con un halo
// cian arriba para dar sensación de profundidad (luz al fondo).
// ---------------------------------------------------------------------
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/bg_landscape.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: WM.panelBottom),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB30D0326), Color(0xE6160E36), Color(0xF50D0326)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.55),
              radius: 1.0,
              colors: [WM.cyan.withValues(alpha: 0.13), Colors.transparent],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------
// PANEL 3D: una "losa" con canto inferior visible, brillo arriba y
// sombra proyectada. El color de acento tiñe el borde y el canto.
// ---------------------------------------------------------------------
class Panel3D extends StatelessWidget {
  const Panel3D({
    super.key,
    required this.child,
    this.accent = WM.cyan,
    this.depth = 6,
    this.radius = 18,
    this.padding = const EdgeInsets.all(14),
    this.glow = 0,
  });

  final Widget child;
  final Color accent;
  final double depth;
  final double radius;
  final EdgeInsets padding;

  /// 0 = sin resplandor, 1 = resplandor completo (para "¡listo para reclamar!")
  final double glow;

  @override
  Widget build(BuildContext context) {
    const double border = 2.5;
    final inner = BorderRadius.circular(radius - border);

    return Container(
      padding: EdgeInsets.only(bottom: depth), // <- lo que asoma = el canto
      decoration: BoxDecoration(
        color: Color.lerp(WM.outline, accent, 0.45),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: WM.outline, width: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: Offset(0, depth + 5),
          ),
          if (glow > 0)
            BoxShadow(
              color: accent.withValues(alpha: 0.45 * glow),
              blurRadius: 22,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: inner,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: inner,
            border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(WM.panelTop, accent, 0.22)!,
                WM.panelTop,
                WM.panelBottom,
              ],
              stops: const [0, 0.35, 1],
            ),
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // Brillo superior (luz cenital)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 26,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// BOTÓN 3D QUE SE HUNDE al pulsarlo. Truco: el margen superior crece y
// el canto inferior se reduce en la misma cantidad, así la altura total
// no cambia (no "salta" el resto de la pantalla).
// ---------------------------------------------------------------------
class Pressable3D extends StatefulWidget {
  const Pressable3D({
    super.key,
    required this.child,
    required this.onTap,
    this.color = WM.cyan,
    this.disabledColor = const Color(0xFF4A4660),
    this.height = 52,
    this.depth = 6,
    this.radius = 12,
    this.slanted = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  final Widget child;
  final VoidCallback? onTap; // null = desactivado
  final Color color;
  final Color disabledColor;
  final double height;
  final double depth;
  final double radius;
  final bool slanted;
  final EdgeInsets padding;

  @override
  State<Pressable3D> createState() => _Pressable3DState();
}

class _Pressable3DState extends State<Pressable3D> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final base = enabled ? widget.color : widget.disabledColor;
    final double sink = _down ? widget.depth - 1.5 : 0;

    Widget content = widget.child;
    if (widget.slanted) {
      content = Transform(
        transform: Matrix4.skewX(-WM.skew),
        alignment: Alignment.center,
        child: content,
      );
    }

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      margin: EdgeInsets.only(top: sink),
      padding: EdgeInsets.only(bottom: widget.depth - sink),
      decoration: BoxDecoration(
        color: shade(base, -0.22), // canto
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: WM.outline, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _down ? 0.3 : 0.5),
            blurRadius: _down ? 4 : 10,
            offset: Offset(0, _down ? 2 : 5),
          ),
        ],
      ),
      child: Container(
        height: widget.height,
        padding: widget.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius - 2.5),
          // Corte duro a la mitad = brillo "glossy" típico de botón de juego
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              shade(base, enabled ? 0.22 : 0.06),
              shade(base, enabled ? 0.10 : 0.03),
              base,
              shade(base, -0.06),
            ],
            stops: const [0, 0.48, 0.52, 1],
          ),
        ),
        child: content,
      ),
    );

    if (widget.slanted) {
      button = Transform(
        transform: Matrix4.skewX(WM.skew),
        alignment: Alignment.center,
        child: button,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setDown(true) : null,
      onTapCancel: enabled ? () => _setDown(false) : null,
      onTapUp: enabled
          ? (_) {
              _setDown(false);
              widget.onTap!();
            }
          : null,
      child: button,
    );
  }
}

// ---------------------------------------------------------------------
// BARRA DE PROGRESO TIPO "TUBO": canal hundido oscuro + relleno con
// volumen y reflejo. Se rellena animada al abrir la pantalla.
// Necesita ancho definido (úsala dentro de Column/Expanded).
// ---------------------------------------------------------------------
class Bar3D extends StatelessWidget {
  const Bar3D({
    super.key,
    required this.value,
    this.color = WM.cyan,
    this.height = 18,
    this.label,
  });

  final double value;
  final Color color;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: WM.outline,
            borderRadius: BorderRadius.circular(height),
            border: Border.all(color: WM.outline, width: 2.5),
            // Filo de luz bajo el canal: parece tallado en el panel
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.10),
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Canal hundido: más oscuro arriba (sombra interior)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF05010F), Color(0xFF241A4C)],
                    ),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [shade(color, 0.22), color, shade(color, -0.2)],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.3,
                        child: Container(
                          margin: EdgeInsets.fromLTRB(height * 0.35, 2, height * 0.35, 0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(height),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (label != null)
                  Center(
                    child: OutlinedGameText(
                      label!,
                      size: height * 0.6,
                      font: GameFont.oswald,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// ENGASTE 3D: aro metálico con brillo especular y un "pozo" oscuro
// dentro, para iconos/emojis (como una gema incrustada).
// ---------------------------------------------------------------------
class Socket3D extends StatelessWidget {
  const Socket3D({
    super.key,
    required this.child,
    this.size = 52,
    this.color = WM.cyan,
  });

  final Widget child;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: WM.outline, width: 2.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shade(color, 0.25), color, shade(color, -0.3)],
        ),
        boxShadow: [
          // Sombra "dura" (sin desenfoque) = canto del engaste
          BoxShadow(color: shade(color, -0.42), offset: const Offset(0, 3.5)),
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 14),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                colors: [Color(0xFF3A2A7A), WM.panelBottom, WM.outline],
                stops: [0, 0.7, 1],
              ),
            ),
          ),
          child,
          // Reflejo especular arriba a la izquierda
          Positioned(
            top: -size * 0.02,
            left: size * 0.08,
            child: Container(
              width: size * 0.26,
              height: size * 0.12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// FICHA PEQUEÑA (recompensas, estrellas…): píldora con sombra dura.
// ---------------------------------------------------------------------
class Chip3D extends StatelessWidget {
  const Chip3D({
    super.key,
    required this.emoji,
    required this.text,
    this.accent = WM.gold,
    this.fontSize = 14,
  });

  final String emoji;
  final String text;
  final Color accent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.65, vertical: fontSize * 0.2),
      decoration: BoxDecoration(
        color: WM.outline,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.8),
        boxShadow: [BoxShadow(color: shade(accent, -0.38), offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: fontSize * 0.9)),
          SizedBox(width: fontSize * 0.3),
          Text(
            text,
            style: GoogleFonts.oswald(
              fontWeight: FontWeight.w700,
              color: accent,
              fontSize: fontSize,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// CABECERA: botón atrás 3D + placa inclinada con el título.
// ---------------------------------------------------------------------
class GameHeader extends StatelessWidget {
  const GameHeader({super.key, required this.title, this.onBack});
  final String title;

  /// Qué hacer al pulsar atrás. Si es null, simplemente cierra la pantalla.
  /// (La Tienda lo usa para devolver el perfil actualizado a la portada.)
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Pressable3D(
            onTap: onBack ?? () => Navigator.maybePop(context),
            color: const Color(0xFF3A2A7A),
            height: 40,
            depth: 5,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: const Icon(Icons.arrow_back_rounded, color: WM.bone, size: 24),
          ),
          Expanded(
            child: Center(
              child: Transform(
                transform: Matrix4.skewX(WM.skew * 0.8),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                  decoration: BoxDecoration(
                    color: WM.outline.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: WM.cyan, width: 2),
                    boxShadow: [
                      BoxShadow(color: WM.cyan.withValues(alpha: 0.3), blurRadius: 16),
                      const BoxShadow(color: Color(0xFF0A6F66), offset: Offset(0, 4)),
                    ],
                  ),
                  child: Transform(
                    transform: Matrix4.skewX(-WM.skew * 0.8),
                    alignment: Alignment.center,
                    child: OutlinedGameText(
                      title,
                      size: 26,
                      letterSpacing: 2,
                      colors: const [WM.cyanLight, WM.cyan],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 50), // equilibra el botón atrás
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// ANIMACIONES
// ---------------------------------------------------------------------

/// Animación en bucle ida y vuelta (t va de 0 a 1 y vuelve).
class LoopAnimation extends StatefulWidget {
  const LoopAnimation({
    super.key,
    required this.builder,
    this.child,
    this.duration = const Duration(milliseconds: 2000),
  });

  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;
  final Duration duration;

  @override
  State<LoopAnimation> createState() => _LoopAnimationState();
}

class _LoopAnimationState extends State<LoopAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..repeat(reverse: true);

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
      builder: (context, child) =>
          widget.builder(context, Curves.easeInOut.transform(_c.value), child),
    );
  }
}

/// Flota arriba y abajo (avatar, corona).
class Bob extends StatelessWidget {
  const Bob({super.key, required this.child, this.amplitude = 6});
  final Widget child;
  final double amplitude;

  @override
  Widget build(BuildContext context) => LoopAnimation(
        duration: const Duration(milliseconds: 1800),
        child: child,
        builder: (context, t, child) =>
            Transform.translate(offset: Offset(0, -amplitude * t), child: child),
      );
}

/// Late suavemente (botón "RECLAMAR").
class Pulse extends StatelessWidget {
  const Pulse({super.key, required this.child, this.amount = 0.06});
  final Widget child;
  final double amount;

  @override
  Widget build(BuildContext context) => LoopAnimation(
        duration: const Duration(milliseconds: 700),
        child: child,
        builder: (context, t, child) =>
            Transform.scale(scale: 1 + amount * t, child: child),
      );
}

/// Entrada en perspectiva: la tarjeta "cae" girando sobre su borde
/// superior hacia el jugador. Las tarjetas entran escalonadas por índice.
class EntranceFlip extends StatelessWidget {
  const EntranceFlip({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int i = index.clamp(0, 6);
    const int stepMs = 70;
    const int baseMs = 450;
    final int totalMs = baseMs + i * stepMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      // Interval = retraso escalonado dentro de la misma animación
      curve: Interval(i * stepMs / totalMs, 1, curve: Curves.easeOutBack),
      child: child,
      builder: (context, t, child) {
        final perspective = Matrix4.identity()
          ..setEntry(3, 2, 0.0015) // <- esto activa la perspectiva
          ..rotateX((1 - t) * 0.9);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.topCenter,
            transform: perspective,
            child: child,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// PINTORES (CustomPainter) para volúmenes que no se pueden hacer con cajas
// ---------------------------------------------------------------------

/// Bloque de podio: cara frontal + cara superior en trapecio (perspectiva).
class PodiumBlockPainter extends CustomPainter {
  PodiumBlockPainter(this.color);
  final Color color;
  static const double topFace = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const inset = 10.0;

    final top = Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..lineTo(w, topFace)
      ..lineTo(0, topFace)
      ..close();
    final front = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, topFace, w, h > topFace ? h - topFace : 0.0),
      bottomLeft: const Radius.circular(6),
      bottomRight: const Radius.circular(6),
    );

    // Sombra en el suelo
    canvas.drawRRect(
      front.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Cara frontal
    canvas.drawRRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, shade(color, -0.3)],
        ).createShader(front.outerRect),
    );
    canvas.save();
    canvas.clipRRect(front);
    // Reflejo vertical a la izquierda y sombra a la derecha = cilindro/bloque
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, topFace + 6, w * 0.1, h),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.8, topFace, w * 0.2, h),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.restore();

    // Cara superior, más clara (le da la luz)
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          colors: [shade(color, 0.22), shade(color, 0.08)],
        ).createShader(Rect.fromLTWH(0, 0, w, topFace)),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..color = WM.outline;
    canvas.drawPath(top, stroke);
    canvas.drawRRect(front, stroke);
  }

  @override
  bool shouldRepaint(PodiumBlockPainter oldDelegate) => oldDelegate.color != color;
}

/// Pedestal cilíndrico con aro brillante, para el avatar del perfil.
class PedestalPainter extends CustomPainter {
  PedestalPainter({this.color = WM.cyan});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final thickness = h * 0.38;
    final topRect = Rect.fromLTWH(0, 0, w, h - thickness);
    final bottomRect = topRect.shift(Offset(0, thickness));

    // Sombra en el suelo
    canvas.drawOval(
      bottomRect.inflate(8).shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Lateral del cilindro (sombreado horizontal = curvatura)
    final sidePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF120A30),
          const Color(0xFF3A2A7A),
          const Color(0xFF120A30),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawOval(bottomRect, sidePaint);
    canvas.drawRect(
      Rect.fromLTRB(0, topRect.center.dy, w, bottomRect.center.dy),
      sidePaint,
    );

    // Cara superior con aro de energía
    canvas.drawOval(
      topRect,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.55), const Color(0xFF2A1A5E)],
        ).createShader(topRect),
    );
    canvas.drawOval(
      topRect.deflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = WM.outline;
    canvas.drawOval(topRect, stroke);
    // Contorno inferior del lateral (solo la mitad visible)
    canvas.drawArc(bottomRect, 0, 3.14159, false, stroke);
    canvas.drawLine(Offset(0, topRect.center.dy), Offset(0, bottomRect.center.dy), stroke);
    canvas.drawLine(Offset(w, topRect.center.dy), Offset(w, bottomRect.center.dy), stroke);
  }

  @override
  bool shouldRepaint(PedestalPainter oldDelegate) => oldDelegate.color != color;
}
