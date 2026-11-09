import 'package:flutter/material.dart';

/// Transición entre pantallas del juego: la pantalla nueva aparece con un
/// fundido y un pequeño "zoom" desde el 94 %, como al abrir un menú de
/// videojuego. Sustituye al deslizamiento lateral de Android (pensado para
/// apps), sin tocar cada Navigator.push: se aplica desde el tema.
class GamePageTransitionsBuilder extends PageTransitionsBuilder {
  const GamePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    // La pantalla de debajo se oscurece un poco al quedar tapada.
    final under = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: enter,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(enter),
        child: AnimatedBuilder(
          animation: under,
          child: child,
          builder: (context, child) => under.value == 0
              ? child!
              : ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.35 * under.value),
              BlendMode.srcATop,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tema con la transición del juego en todas las plataformas.
const PageTransitionsTheme kGamePageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: GamePageTransitionsBuilder(),
    TargetPlatform.iOS: GamePageTransitionsBuilder(),
    TargetPlatform.windows: GamePageTransitionsBuilder(),
    TargetPlatform.macOS: GamePageTransitionsBuilder(),
    TargetPlatform.linux: GamePageTransitionsBuilder(),
    TargetPlatform.fuchsia: GamePageTransitionsBuilder(),
  },
);
