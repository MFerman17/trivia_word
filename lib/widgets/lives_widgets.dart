import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/lives_service.dart';
import '../services/save_service.dart';
import 'game_3d.dart';
import '../l10n/l10n.dart';

/// "mm:ss" para el contador de la siguiente vida.
String formatLifeTimer(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Contador de vidas: corazón con el número y, si no están llenas, el
/// tiempo para la siguiente. Se actualiza solo cada segundo.
class LivesBadge extends StatefulWidget {
  const LivesBadge({super.key, this.onTap});

  /// Al tocarlo (por ejemplo, para abrir el diálogo de recargar).
  final VoidCallback? onTap;

  @override
  State<LivesBadge> createState() => _LivesBadgeState();
}

class _LivesBadgeState extends State<LivesBadge> {
  Timer? _timer;
  Duration? _next;

  @override
  void initState() {
    super.initState();
    _next = LivesService.timeToNextLifeCached;
    // La primera comprobación, justo después de dibujar (no durante).
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  // Se calcula aquí (no en build) porque puede sumar una vida recargada,
  // y eso avisa a otras pantallas: no se puede hacer mientras se dibuja.
  void _tick() {
    final next = LivesService.timeToNextLife;
    if (mounted) setState(() => _next = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LivesService.lives,
      builder: (context, lives, _) {
        final empty = lives == 0;
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
            decoration: BoxDecoration(
              color: WM.outline.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: empty ? const Color(0xFFFF4D5E) : const Color(0x88FF4D5E),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFFF4D5E), size: 28),
                    Text(
                      '$lives',
                      style: GoogleFonts.anton(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Text(
                  _next == null ? context.l10n.livesFull : formatLifeTimer(_next!),
                  style: GoogleFonts.oswald(
                    color: _next == null ? Colors.white70 : WM.bone,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

/// Comprueba que quedan vidas antes de empezar un nivel o una pelea.
/// Si no quedan, muestra el diálogo para recargar. Devuelve true si se
/// puede jugar.
Future<bool> ensureLives(BuildContext context) async {
  LivesService.refresh();
  if (LivesService.hasLives) return true;
  await showOutOfLivesDialog(context);
  return LivesService.hasLives;
}

/// Al tocar el contador de vidas: solo abre el diálogo si no quedan.
void showOutOfLivesDialogIfEmpty(BuildContext context) {
  LivesService.refresh();
  if (!LivesService.hasLives) showOutOfLivesDialog(context);
}

/// Diálogo "Sin vidas": esperar, poción, video o gemas.
Future<void> showOutOfLivesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => const _OutOfLivesDialog(),
  );
}

class _OutOfLivesDialog extends StatefulWidget {
  const _OutOfLivesDialog();

  @override
  State<_OutOfLivesDialog> createState() => _OutOfLivesDialogState();
}

class _OutOfLivesDialogState extends State<_OutOfLivesDialog> {
  int _potions = 0;
  int _gems = 0;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  bool _closed = false;

  /// Cierra el diálogo UNA sola vez. Durante la animación de cierre el
  /// diálogo sigue "vivo" un instante; sin esta marca, el contador podría
  /// cerrar también la pantalla de debajo.
  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    SaveService.loadPlayerData().then((p) {
      if (mounted) {
        setState(() {
          _potions = p.healthPotions;
          _gems = p.gems;
        });
      }
    });
    // Si mientras está abierto se recarga una vida, se cierra solo.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      LivesService.refresh();
      if (!mounted || _closed) return;
      if (LivesService.hasLives) {
        _close();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _usePotion() async {
    final profile = await SaveService.loadPlayerData();
    if (profile.healthPotions <= 0) return;
    profile.healthPotions--;
    await SaveService.savePlayerData(profile);
    LivesService.addLives(1);
    AudioService.playPotionUse();
    _close();
  }

  Future<void> _useGems() async {
    final profile = await SaveService.loadPlayerData();
    if (profile.gems < LivesService.gemsForFullRefill) return;
    profile.gems -= LivesService.gemsForFullRefill;
    await SaveService.savePlayerData(profile);
    LivesService.refillAll();
    AudioService.playRevive();
    _close();
  }

  Future<void> _watchAd() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // Igual que al revivir: los anuncios solo funcionan en Android; en
    // modo debug fuera de Android se simula para poder probar.
    final adsSupported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final earned = !adsSupported && kDebugMode
        ? await Future<bool>.delayed(const Duration(seconds: 1), () => true)
        : await AdService.showRewardedAd();
    if (!mounted) return;
    if (earned) {
      LivesService.addLives(1);
      AudioService.playRevive();
      _close();
    } else {
      setState(() {
        _busy = false;
        _error = context.l10n.noVideosNow;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFFF4D5E);
    final next = LivesService.timeToNextLifeCached;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: Panel3D(
        accent: danger,
        glow: 0.5,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedGameText(
              context.l10n.outOfLives,
              size: 28,
              letterSpacing: 2,
              colors: const [Color(0xFFFFB3BA), danger],
            ),
            const SizedBox(height: 8),
            const Text('💔', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? context.l10n.refillToPlay
                  : context.l10n.nextLifeIn(formatLifeTimer(next)),
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 14),
            _option(
              emoji: '🎬',
              label: context.l10n.watchVideoPlusOne,
              color: WM.gold,
              loading: _busy,
              onTap: _busy ? null : _watchAd,
            ),
            const SizedBox(height: 10),
            _option(
              emoji: '🧪',
              label: _potions > 0 ? context.l10n.usePotionPlusOne(_potions) : context.l10n.noPotions,
              color: WM.cyan,
              onTap: _potions > 0 && !_busy ? _usePotion : null,
            ),
            const SizedBox(height: 10),
            _option(
              emoji: '💎',
              label: context.l10n.gemsRefillAll(LivesService.gemsForFullRefill),
              color: WM.violet,
              onTap: _gems >= LivesService.gemsForFullRefill && !_busy ? _useGems : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(color: const Color(0xFFFFB3BA), fontSize: 12),
              ),
            ],
            TextButton(
              onPressed: _busy ? null : _close,
              child: Text(
                context.l10n.wait,
                style: GoogleFonts.oswald(
                  color: Colors.white54,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Pressable3D(
        onTap: onTap,
        color: color,
        height: 46,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3, color: WM.outline),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: OutlinedGameText(label, size: 15, font: GameFont.oswald),
                  ),
                ],
              ),
      ),
    );
  }
}
