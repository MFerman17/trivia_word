import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import 'game_3d.dart';

/// Pregunta "¿Seguro que quieres salir?" antes de abandonar un nivel o una
/// pelea. Devuelve true si el jugador confirma.
///
/// El botón destacado es SEGUIR JUGANDO (el que más se pulsa por error es
/// el de salir, así que no debe ser el más llamativo).
Future<bool> showLeaveConfirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  AudioService.playButtonClick();
  final leave = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'leave',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (dialogContext, _, _) {
      final l = dialogContext.l10n;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            type: MaterialType.transparency,
            child: Panel3D(
              accent: const Color(0xFFFF4D5E),
              radius: 20,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: OutlinedGameText(
                      title,
                      size: 22,
                      colors: const [Color(0xFFFFB3BA), Color(0xFFFF4D5E)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Pressable3D(
                      onTap: () {
                        AudioService.playButtonClick();
                        Navigator.of(dialogContext).pop(false);
                      },
                      color: WM.cyan,
                      height: 48,
                      child: OutlinedGameText(l.leaveKeepPlaying, size: 17, font: GameFont.oswald),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      AudioService.playButtonClick();
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: Text(
                      l.leaveConfirm,
                      style: GoogleFonts.oswald(
                        color: const Color(0xFFFF9DA6),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
  return leave ?? false;
}
