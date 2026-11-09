import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/streak_service.dart';
import 'game_3d.dart';
import 'game_icon.dart';
import 'victory_fx.dart';

/// Abre el calendario de la racha de 7 días. Devuelve true si el jugador
/// reclamó el premio de hoy (para refrescar monedas y gemas en la portada).
Future<bool> showStreakCalendar(BuildContext context, PlayerProfile profile) async {
  final status = await StreakService.status();
  if (!context.mounted) return false;
  final claimed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'streak',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => _StreakDialog(profile: profile, status: status),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
  return claimed ?? false;
}

class _StreakDialog extends StatefulWidget {
  const _StreakDialog({required this.profile, required this.status});

  final PlayerProfile profile;
  final StreakStatus status;

  @override
  State<_StreakDialog> createState() => _StreakDialogState();
}

class _StreakDialogState extends State<_StreakDialog> {
  late bool _canClaim = widget.status.canClaim;
  bool _justClaimed = false;
  bool _busy = false;

  /// Día que se ve resaltado: el de hoy.
  int get _today => widget.status.day;

  Future<void> _claim() async {
    if (_busy || !_canClaim) return;
    setState(() => _busy = true);
    final reward = await StreakService.claim(widget.profile);
    if (!mounted) return;
    if (reward != null) {
      AudioService.playChestOpen();
      Future.delayed(const Duration(milliseconds: 350), AudioService.playCoins);
    }
    setState(() {
      _busy = false;
      _canClaim = false;
      _justClaimed = reward != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Stack(
      children: [
        if (_justClaimed) const Positioned.fill(child: IgnorePointer(child: ConfettiLayer(pieces: 70))),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              type: MaterialType.transparency,
              child: Panel3D(
                accent: const Color(0xFFFF8A3D),
                glow: _canClaim ? 0.6 : 0.2,
                radius: 22,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedGameText(
                      l.streakTitle,
                      size: 28,
                      letterSpacing: 2,
                      colors: const [Color(0xFFFFE0A0), Color(0xFFFF8A3D)],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.status.lost ? l.streakLost : l.streakSubtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oswald(
                        color: widget.status.lost ? const Color(0xFFFF9DA6) : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Días 1-6 en dos filas de tres y el día 7, el gran premio,
                    // a lo ancho debajo: así se ve que es el especial.
                    for (final row in const [
                      [1, 2, 3],
                      [4, 5, 6],
                    ]) ...[
                      Row(
                        children: [
                          for (final d in row) ...[
                            Expanded(child: _tile(d)),
                            if (d != row.last) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    _tile(7, wide: true),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: Pressable3D(
                        onTap: _canClaim
                            ? _claim
                            : () {
                                AudioService.playButtonClick();
                                Navigator.of(context).pop(_justClaimed);
                              },
                        color: _canClaim ? const Color(0xFFFF8A3D) : WM.cyan,
                        height: 50,
                        child: OutlinedGameText(
                          _canClaim ? l.streakClaim : l.continueButton,
                          size: 18,
                          font: GameFont.oswald,
                        ),
                      ),
                    ),
                    if (!_canClaim) ...[
                      const SizedBox(height: 8),
                      Text(
                        l.streakComeBack(_today % StreakService.rewards.length + 1),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.oswald(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Casilla de un día: reclamado (con marca), hoy (brilla) o por llegar.
  Widget _tile(int day, {bool wide = false}) {
    final l = context.l10n;
    final r = StreakService.rewards[day - 1];
    // Antes de reclamar, el de hoy aún no cuenta como hecho.
    final done = day < _today || (day == _today && !_canClaim);
    final isToday = day == _today && _canClaim;
    final accent = day == 7 ? WM.gold : const Color(0xFFFF8A3D);
    final items = [
      if (r.coins > 0) ('🪙', r.coins),
      if (r.gems > 0) ('💎', r.gems),
      if (r.hints > 0) ('💡', r.hints),
      if (r.potions > 0) ('🧪', r.potions),
      if (r.keys > 0) ('🗝️', r.keys),
    ];
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: done ? const Color(0xFF1C3A2E) : const Color(0xFF1B1240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? accent : (done ? WM.green : Colors.white24),
          width: isToday ? 2.5 : 1.5,
        ),
        boxShadow: isToday ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 14)] : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: done ? 0.45 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.streakDay(day),
                  style: GoogleFonts.oswald(
                    color: isToday ? accent : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: wide ? 12 : 4,
                  runSpacing: 2,
                  children: [
                    for (final (emoji, n) in items)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GameIcon(emoji, size: wide ? 20 : 15),
                          Text(
                            '$n',
                            style: GoogleFonts.anton(color: Colors.white, fontSize: wide ? 16 : 13),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (done)
            TweenAnimationBuilder<double>(
              // La marca del día recién reclamado entra con un rebote.
              tween: Tween(begin: day == _today && _justClaimed ? 0 : 1, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, s, child) => Transform.scale(scale: s, child: child),
              child: const Icon(Icons.check_circle_rounded, color: WM.green, size: 30),
            ),
        ],
      ),
    );
    return isToday ? Pulse(amount: 0.05, child: tile) : tile;
  }
}
