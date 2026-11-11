import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/age_gate_service.dart';
import '../services/audio_service.dart';
import 'game_3d.dart';

/// Pregunta el año de nacimiento (una sola vez, al abrir el juego).
///
/// Es "neutral" como pide Google: la rueda empieza en el año actual (no en
/// un año de adulto), no se explica qué edad hace falta y el botón no se
/// activa hasta que el jugador elige un año.
Future<void> showAgeGate(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'age',
    barrierColor: Colors.black.withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => const _AgeGateDialog(),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _AgeGateDialog extends StatefulWidget {
  const _AgeGateDialog();

  @override
  State<_AgeGateDialog> createState() => _AgeGateDialogState();
}

class _AgeGateDialogState extends State<_AgeGateDialog> {
  static const int _span = 100;
  final int _thisYear = DateTime.now().year;
  int? _year;

  Future<void> _confirm() async {
    final year = _year;
    if (year == null) return;
    AudioService.playButtonClick();
    await AgeGateService.setBirthYear(year);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            type: MaterialType.transparency,
            child: Panel3D(
              accent: WM.cyan,
              radius: 22,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(fit: BoxFit.scaleDown, child: OutlinedGameText(l.ageTitle, size: 22)),
                  const SizedBox(height: 6),
                  Text(
                    l.ageSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Franja que marca el año elegido.
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: WM.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: WM.cyan.withValues(alpha: 0.6)),
                          ),
                        ),
                        ListWheelScrollView.useDelegate(
                          itemExtent: 40,
                          diameterRatio: 1.6,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) => setState(() => _year = _thisYear - i),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _span,
                            builder: (_, i) => Center(
                              child: Text(
                                '${_thisYear - i}',
                                style: GoogleFonts.anton(color: Colors.white, fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: Opacity(
                      opacity: _year == null ? 0.4 : 1,
                      child: Pressable3D(
                        onTap: _year == null ? null : _confirm,
                        color: WM.cyan,
                        height: 48,
                        child: OutlinedGameText(l.ageConfirm, size: 17, font: GameFont.oswald),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
