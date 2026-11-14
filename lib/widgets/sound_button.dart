import 'package:flutter/material.dart';

import '../services/audio_service.dart';

/// Botón de altavoz que silencia o activa todo el sonido.
///
/// Escucha [AudioService.mutedNotifier], así que siempre muestra el estado
/// REAL aunque el sonido se cambie en otra pantalla o en Ajustes. Antes cada
/// pantalla guardaba su propia copia y se desincronizaban.
///
/// [builder] permite dibujarlo con el estilo de cada pantalla; si no se
/// da, es un IconButton sencillo.
class SoundToggleButton extends StatelessWidget {
  const SoundToggleButton({
    super.key,
    this.onColor = const Color(0xFFFFC857),
    this.size = 24,
    this.compact = false,
    this.builder,
  });

  final Color onColor;
  final double size;
  final bool compact;
  final Widget Function(BuildContext context, bool muted, VoidCallback toggle)? builder;

  static void toggle() => AudioService.toggleMute();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioService.mutedNotifier,
      builder: (context, muted, _) {
        final custom = builder;
        if (custom != null) return custom(context, muted, toggle);
        return IconButton(
          visualDensity: compact ? VisualDensity.compact : null,
          icon: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: muted ? Colors.redAccent : onColor,
            size: size,
          ),
          onPressed: toggle,
        );
      },
    );
  }
}
