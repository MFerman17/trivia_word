import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/save_service.dart';
import '../services/vibration_service.dart';

/// Monstruos que cruzan el mapa volando y lanzan cosas.
///
/// Cómo funciona:
///  - Cada 8-18 segundos aparece un monstruo por un lado de la pantalla y
///    cruza hasta el otro en ondas, en unos 7 segundos.
///  - Por el camino escupe 1 o 2 proyectiles (fuego, rayos, rocas, hojas,
///    según el mundo). Al caer dejan una marca que se apaga sola: es el
///    "efecto en el mundo", solo visual.
///  - Si el jugador lo toca antes de que se vaya, el monstruo recibe el golpe
///    y suelta monedas (a veces una gema).
///  - Máximo [dailyCatches] capturas con premio al día, para que sea un extra
///    divertido y no una forma de sacar monedas sin fin.
///
/// Todo se dibuja en una capa por encima del mapa. Solo el monstruo recibe
/// toques; el resto deja pasar los toques a los niveles de debajo.
class FlyingMonsters extends StatefulWidget {
  const FlyingMonsters({super.key, required this.world});

  final int world;

  static const int dailyCatches = 8;

  @override
  State<FlyingMonsters> createState() => _FlyingMonstersState();
}

class _Flyer {
  _Flyer({
    required this.start,
    required this.fromLeft,
    required this.y,
    required this.wave,
    required this.asset,
    required this.isDragon,
    required this.shots,
  });

  final Duration start;
  final bool fromLeft;
  final double y; // altura base, 0..1 de la pantalla
  final double wave; // amplitud de la onda en píxeles
  final String asset;
  final bool isDragon;
  final List<double> shots; // momentos (0..1 del vuelo) en que dispara
  int fired = 0;
  Duration? hitAt; // cuándo lo tocó el jugador
}

class _Shot {
  _Shot(this.start, this.from, this.to);
  final Duration start;
  final Offset from;
  final Offset to;
}

class _Mark {
  _Mark(this.start, this.at, {this.text});
  final Duration start;
  final Offset at;
  final String? text; // texto del premio (+12 🪙) o null = marca del impacto
}

class _FlyingMonstersState extends State<FlyingMonsters> with SingleTickerProviderStateMixin {
  static const Duration flight = Duration(milliseconds: 7000);
  static const Duration shotTime = Duration(milliseconds: 900);
  static const Duration markTime = Duration(milliseconds: 3500);
  static const double size = 100;

  final math.Random _rnd = math.Random();
  late final Ticker _ticker;
  Duration _now = Duration.zero;
  Timer? _spawnTimer;
  Size _area = Size.zero;

  _Flyer? _flyer;
  final List<_Shot> _shots = [];
  final List<_Mark> _marks = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _scheduleNext(first: true);
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Datos de cada mundo
  // ------------------------------------------------------------------
  String get _monsterName => switch (widget.world) {
        2 => 'mini_cave_bat',
        3 => 'mini_sky_familiar',
        4 => 'mini_lava_salamander',
        _ => 'mini_forest_guardian',
      };

  /// Lo que lanza el monstruo de cada mundo (el dragón siempre escupe fuego).
  String _projectile(bool dragon) => dragon
      ? '🔥'
      : switch (widget.world) {
          2 => '🪨',
          3 => '⚡',
          4 => '🔥',
          _ => '🍃',
        };

  /// Marca que deja al caer.
  String _impact(bool dragon) => dragon
      ? '💥'
      : switch (widget.world) {
          2 => '💨',
          3 => '✨',
          4 => '💥',
          _ => '🌿',
        };

  // ------------------------------------------------------------------
  // Aparición
  // ------------------------------------------------------------------
  void _scheduleNext({bool first = false}) {
    _spawnTimer?.cancel();
    final seconds = first ? 4 + _rnd.nextInt(4) : 8 + _rnd.nextInt(11);
    _spawnTimer = Timer(Duration(seconds: seconds), _spawn);
  }

  void _spawn() {
    if (!mounted) return;
    // Cada mundo tiene su propia criatura voladora (ver assets/images/flyers).
    const dragon = false;
    final shots = [0.25 + _rnd.nextDouble() * 0.2, if (_rnd.nextBool()) 0.6 + _rnd.nextDouble() * 0.2];
    setState(() {
      _flyer = _Flyer(
        start: _now,
        fromLeft: _rnd.nextBool(),
        y: 0.15 + _rnd.nextDouble() * 0.45,
        wave: 18 + _rnd.nextDouble() * 22,
        asset: 'assets/images/flyers/flyer_w${widget.world.clamp(1, 4)}_1.png',
        isDragon: dragon,
        shots: shots,
      );
    });
  }

  // ------------------------------------------------------------------
  // Movimiento
  // ------------------------------------------------------------------
  Offset? _flyerCenter(_Flyer f) {
    final t = (_now - f.start).inMilliseconds / flight.inMilliseconds;
    if (t > 1) return null;
    final w = _area.width + size * 2;
    final x = f.fromLeft ? -size + w * t : _area.width + size - w * t;
    final y = f.y * _area.height + math.sin(t * math.pi * 4) * f.wave;
    // Al recibir el golpe cae girando.
    if (f.hitAt != null) {
      final fall = (_now - f.hitAt!).inMilliseconds / 1000;
      return Offset(x, y + fall * fall * 600);
    }
    return Offset(x, y);
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    final f = _flyer;
    final busy = f != null || _shots.isNotEmpty || _marks.isNotEmpty;
    if (!busy || _area == Size.zero) return;

    if (f != null) {
      final t = (_now - f.start).inMilliseconds / flight.inMilliseconds;
      final pos = _flyerCenter(f);
      // Dispara cuando llega su momento (si no lo han tocado).
      if (f.hitAt == null && f.fired < f.shots.length && t >= f.shots[f.fired] && pos != null) {
        f.fired++;
        final target = Offset(
          (pos.dx + (_rnd.nextDouble() - 0.5) * 160).clamp(30, _area.width - 30).toDouble(),
          (pos.dy + 160 + _rnd.nextDouble() * 200).clamp(60, _area.height - 40).toDouble(),
        );
        _shots.add(_Shot(_now, pos + Offset(f.fromLeft ? 20 : -20, 20), target));
        if (f.isDragon || widget.world == 4) AudioService.playSfx('fire.mp3', fallback: 'attack.mp3');
      }
      final gone = pos == null ||
          (f.hitAt != null && (_now - f.hitAt!) > const Duration(milliseconds: 1200));
      if (gone) {
        _flyer = null;
        _scheduleNext();
      }
    }

    // Los proyectiles que llegan dejan su marca.
    _shots.removeWhere((s) {
      if (_now - s.start < shotTime) return false;
      _marks.add(_Mark(_now, s.to));
      return true;
    });
    _marks.removeWhere((m) => _now - m.start > markTime);
    setState(() {});
  }

  // ------------------------------------------------------------------
  // Toque: premio
  // ------------------------------------------------------------------
  Future<void> _hit() async {
    final f = _flyer;
    if (f == null || f.hitAt != null) return;
    final pos = _flyerCenter(f);
    f.hitAt = _now;
    AudioService.playMonsterHit();
    VibrationService.hit();
    if (pos == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'flyers_${now.year}-${now.month}-${now.day}';
    final caught = prefs.getInt(key) ?? 0;
    if (caught >= FlyingMonsters.dailyCatches) {
      _marks.add(_Mark(_now, pos, text: L10n.current.flyerNoMoreToday));
      return;
    }
    await prefs.setInt(key, caught + 1);

    final coins = 5 + _rnd.nextInt(11) + (f.isDragon ? 10 : 0);
    final gem = _rnd.nextDouble() < (f.isDragon ? 0.25 : 0.08);
    final profile = await SaveService.loadPlayerData();
    profile.coins += coins;
    if (gem) profile.gems += 1;
    await SaveService.savePlayerData(profile);
    AudioService.playCoins();
    if (!mounted) return;
    setState(() {
      _marks.add(_Mark(_now, pos, text: gem ? '+$coins 🪙  +1 💎' : '+$coins 🪙'));
    });
  }

  // ------------------------------------------------------------------
  // Dibujo
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _area = Size(constraints.maxWidth, constraints.maxHeight);
        final f = _flyer;
        final pos = f == null ? null : _flyerCenter(f);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Marcas de impacto y textos de premio (no reciben toques).
            for (final m in _marks) _buildMark(m),
            for (final s in _shots) _buildShot(s),
            if (f != null && pos != null) _buildFlyer(f, pos),
          ],
        );
      },
    );
  }

  Widget _buildFlyer(_Flyer f, Offset pos) {
    final hit = f.hitAt != null;
    final spin = hit ? (_now - f.hitAt!).inMilliseconds / 1000 * 6 : 0.0;
    // Aleteo: se alternan dos dibujos (alas arriba / alas abajo) cada 140 ms.
    // Si aún no existen las imágenes de la criatura voladora del mundo, se
    // usa el monstruo del mundo, que "aletea" estirándose un poco.
    final flapUp = (_now.inMilliseconds ~/ 140).isEven;
    final frame = 'assets/images/flyers/flyer_w${widget.world.clamp(1, 4)}_${flapUp || hit ? 1 : 2}.png';
    final fallback = Transform.scale(
      scaleY: hit ? 1 : (flapUp ? 1.0 : 0.88),
      child: Image.asset(
        'assets/images/monsters/${_monsterName}_${hit ? 'hit' : 'idle'}.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('🐉', style: TextStyle(fontSize: 50)),
      ),
    );
    // Las criaturas miran a la izquierda: si vuelan hacia la derecha se voltean.
    final image = Transform.flip(
      flipX: f.fromLeft,
      child: Image.asset(
        frame,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
    const w = size;
    return Positioned(
      left: pos.dx - w / 2,
      top: pos.dy - size / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _hit,
        child: Transform.rotate(
          angle: spin,
          child: Opacity(opacity: hit ? 0.85 : 1, child: image),
        ),
      ),
    );
  }

  Widget _buildShot(_Shot s) {
    final t = ((_now - s.start).inMilliseconds / shotTime.inMilliseconds).clamp(0.0, 1.0);
    // Cae en curva (como si tuviera peso).
    final x = s.from.dx + (s.to.dx - s.from.dx) * t;
    final y = s.from.dy + (s.to.dy - s.from.dy) * t * t;
    final dragon = _flyer?.isDragon ?? false;
    return Positioned(
      left: x - 14,
      top: y - 14,
      child: IgnorePointer(
        child: Text(_projectile(dragon || widget.world == 4), style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  Widget _buildMark(_Mark m) {
    final t = ((_now - m.start).inMilliseconds / markTime.inMilliseconds).clamp(0.0, 1.0);
    final opacity = (1 - t).clamp(0.0, 1.0);
    if (m.text != null) {
      // Premio: sube y se desvanece.
      return Positioned(
        left: m.at.dx - 70,
        top: m.at.dy - 20 - t * 60,
        width: 140,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Text(
              m.text!,
              textAlign: TextAlign.center,
              style: GoogleFonts.anton(
                color: const Color(0xFFFFE37A),
                fontSize: 20,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ),
        ),
      );
    }
    // Impacto: un destello que crece y luego una mancha que se apaga.
    final scale = t < 0.15 ? t / 0.15 * 1.4 : 1.0;
    return Positioned(
      left: m.at.dx - 30,
      top: m.at.dy - 30,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 54,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: RadialGradient(
                      colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                    ),
                  ),
                ),
                Transform.scale(
                  scale: scale,
                  child: Text(_impact(_flyer?.isDragon ?? false), style: const TextStyle(fontSize: 30)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
