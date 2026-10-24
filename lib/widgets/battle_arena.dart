import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import 'game_3d.dart';
import 'player_avatar.dart';

/// Escenario del combate: el monstruo grande, "de pie" sobre un pedestal,
/// con sensación de 3D, y el jugador pequeño en la esquina.
///
/// No es un modelo 3D de verdad (eso necesitaría archivos .glb hechos en
/// Blender). Es "2,5D": la imagen se inclina con perspectiva, respira,
/// flota sobre su sombra y reacciona a cada respuesta. Con las imágenes
/// que ya tenemos se consigue que el monstruo parezca salir de la pantalla.
///
/// Cómo se comunica con la pantalla de combate:
///  - [hitCount] sube en 1 cada vez que el jugador acierta → el monstruo
///    recibe el golpe (se sacude, destella y salta el número de daño).
///  - [attackCount] sube en 1 cada vez que el jugador falla → el monstruo
///    se abalanza hacia la pantalla y todo tiembla en rojo.
///  - [enemyHp] = 0 → el monstruo cae derrotado.
class BattleArena extends StatefulWidget {
  const BattleArena({
    super.key,
    required this.enemyAsset,
    required this.enemyEmoji,
    required this.enemyName,
    required this.encounterLabel,
    required this.isBoss,
    required this.enemyHp,
    required this.enemyMaxHp,
    required this.hitCount,
    required this.attackCount,
    required this.lastDamage,
    this.profile,
    this.compact = false,
  });

  final String enemyAsset;
  final String enemyEmoji;
  final String enemyName;
  final String encounterLabel;
  final bool isBoss;
  final int enemyHp;
  final int enemyMaxHp;
  final int hitCount;
  final int attackCount;
  final int lastDamage;
  final PlayerProfile? profile;

  /// Más bajo mientras se lee la explicación de la respuesta.
  final bool compact;

  @override
  State<BattleArena> createState() => _BattleArenaState();
}

class _BattleArenaState extends State<BattleArena> with TickerProviderStateMixin {
  // Movimiento continuo: respiración, flotación y giro suave.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  // Aparición al empezar la batalla (sube desde abajo y crece).
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  // Golpe recibido (acierto del jugador).
  late final AnimationController _hit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // Ataque del monstruo (fallo del jugador).
  late final AnimationController _attack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  // Derrota del monstruo.
  late final AnimationController _defeat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(BattleArena old) {
    super.didUpdateWidget(old);
    if (widget.hitCount > old.hitCount) _hit.forward(from: 0);
    if (widget.attackCount > old.attackCount) _attack.forward(from: 0);
    if (widget.enemyHp <= 0 && old.enemyHp > 0) {
      // Primero se ve el golpe y luego cae.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _defeat.forward(from: 0);
      });
    } else if (widget.enemyHp > 0 && _defeat.value > 0) {
      _defeat.value = 0; // Por si revive la batalla.
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _entrance.dispose();
    _hit.dispose();
    _attack.dispose();
    _defeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isBoss ? const Color(0xFFFF8A3D) : WM.cyan;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      height: widget.compact ? 170 : 250,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _entrance, _hit, _attack, _defeat]),
        builder: (context, _) {
          // Temblor de todo el escenario cuando ataca el monstruo.
          final attackT = _attack.value;
          final quake = attackT > 0 && attackT < 0.7
              ? math.sin(attackT * math.pi * 14) * 7 * (1 - attackT / 0.7)
              : 0.0;

          return Transform.translate(
            offset: Offset(quake, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Nombre, tipo de encuentro y vida del monstruo.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildStatusPlate(accent),
                ),
                // Monstruo sobre su pedestal.
                Positioned.fill(
                  top: 52,
                  child: _buildMonster(accent),
                ),
                // El jugador, pequeño, en la esquina (como en los RPG).
                if (widget.profile != null)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: _buildPlayer(),
                  ),
                // Destello rojo cuando el monstruo golpea.
                if (attackT > 0 && attackT < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: RadialGradient(
                            radius: 1.1,
                            colors: [
                              Colors.transparent,
                              const Color(0xFFFF2D4A).withValues(
                                alpha: 0.45 * math.sin(attackT * math.pi),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // PLACA DE ESTADO
  // ---------------------------------------------------------------
  Widget _buildStatusPlate(Color accent) {
    final ratio = widget.enemyMaxHp == 0 ? 0.0 : widget.enemyHp / widget.enemyMaxHp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: OutlinedGameText(
                      widget.enemyName.toUpperCase(),
                      size: 17,
                      font: GameFont.oswald,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.encounterLabel,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Bar3D(
                value: ratio,
                height: 18,
                color: ratio > 0.5
                    ? const Color(0xFFFF4D5E)
                    : ratio > 0.25
                        ? const Color(0xFFFF8A3D)
                        : const Color(0xFFFFC93C),
                label: '${widget.enemyHp} / ${widget.enemyMaxHp}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // MONSTRUO
  // ---------------------------------------------------------------
  Widget _buildMonster(Color accent) {
    final t = _idle.value * 2 * math.pi;
    final entrance = Curves.easeOutBack.transform(_entrance.value.clamp(0.0, 1.0));
    final hitT = _hit.value;
    final attackT = _attack.value;
    final defeatT = Curves.easeIn.transform(_defeat.value);

    // Respiración y flotación.
    final bob = math.sin(t) * 6;
    final breathe = 1 + math.sin(t * 2) * 0.025;
    // Giro suave a izquierda y derecha: es lo que da la sensación de volumen.
    final sway = math.sin(t) * 0.16;

    // Golpe: sacudida lateral que se va apagando y destello blanco.
    final shake = hitT > 0 && hitT < 1 ? math.sin(hitT * math.pi * 10) * 12 * (1 - hitT) : 0.0;
    final flash = hitT > 0 && hitT < 0.5 ? (1 - hitT * 2) : 0.0;

    // Ataque: se echa atrás y luego se lanza hacia la pantalla (crece y baja).
    final lunge = attackT == 0
        ? 0.0
        : attackT < 0.25
            ? -0.4 * (attackT / 0.25)
            : attackT < 0.5
                ? -0.4 + 1.4 * ((attackT - 0.25) / 0.25)
                : 1.0 - (attackT - 0.5) / 0.5;

    final scale = (widget.isBoss ? 1.12 : 1.0) *
        breathe *
        (0.55 + 0.45 * entrance) *
        (1 + 0.35 * lunge.clamp(0.0, 1.0)) *
        (1 - 0.4 * defeatT);

    return LayoutBuilder(
      builder: (context, box) {
        final monsterHeight = box.maxHeight * 0.92;
        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Aura del jefe (late detrás).
            if (widget.isBoss)
              Positioned(
                bottom: 10,
                child: Container(
                  width: monsterHeight * 1.2,
                  height: monsterHeight * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.35 + 0.15 * math.sin(t * 2)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            // Pedestal.
            Positioned(
              bottom: 0,
              child: Opacity(
                opacity: entrance.clamp(0.0, 1.0),
                child: CustomPaint(
                  size: const Size(170, 46),
                  painter: PedestalPainter(color: accent),
                ),
              ),
            ),
            // Sombra: se encoge cuando el monstruo sube.
            Positioned(
              bottom: 16,
              child: Container(
                width: 110 - bob * 2,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: Colors.black.withValues(alpha: 0.45 * (1 - defeatT)),
                ),
              ),
            ),
            // El monstruo.
            Positioned(
              bottom: 22,
              child: Opacity(
                opacity: (1 - defeatT).clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // perspectiva
                    ..translateByDouble(
                      shake,
                      -bob + 40 * (1 - entrance) + 30 * lunge.clamp(0.0, 1.0) + 30 * defeatT,
                      0,
                      1,
                    )
                    ..rotateY(sway)
                    ..rotateX(-0.08 + 0.25 * lunge.clamp(0.0, 1.0))
                    ..rotateZ(0.6 * defeatT)
                    ..scaleByDouble(scale, scale, 1, 1),
                  child: SizedBox(
                    height: monsterHeight,
                    width: monsterHeight * 1.1,
                    child: ColorFiltered(
                      // srcATop pinta solo sobre la silueta: destello blanco al
                      // recibir el golpe, sin pintar el fondo transparente.
                      colorFilter: ColorFilter.mode(
                        Colors.white.withValues(alpha: 0.85 * flash),
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(
                        widget.enemyAsset,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        cacheWidth: 512,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            widget.enemyEmoji,
                            style: TextStyle(fontSize: monsterHeight * 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Número de daño que salta hacia arriba.
            if (hitT > 0 && hitT < 1 && widget.lastDamage > 0)
              Positioned(
                bottom: monsterHeight * 0.55 + 70 * hitT,
                child: Opacity(
                  opacity: (1 - hitT).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.8 + 0.6 * Curves.elasticOut.transform(hitT.clamp(0.0, 1.0)),
                    child: OutlinedGameText(
                      '-${widget.lastDamage}',
                      size: 34,
                      colors: const [Color(0xFFFFF1B0), Color(0xFFFF4D5E)],
                    ),
                  ),
                ),
              ),
            // Chispa del impacto (el emoji va fuera del texto con contorno).
            if (hitT > 0 && hitT < 0.6)
              Positioned(
                bottom: monsterHeight * 0.4,
                child: Transform.scale(
                  scale: 0.6 + hitT * 1.8,
                  child: Opacity(
                    opacity: (1 - hitT / 0.6).clamp(0.0, 1.0),
                    child: const Text('💥', style: TextStyle(fontSize: 54)),
                  ),
                ),
              ),
            // Zarpazo cuando el monstruo ataca.
            if (attackT > 0.35 && attackT < 0.85)
              Positioned(
                bottom: monsterHeight * 0.15,
                child: Opacity(
                  opacity: math.sin((attackT - 0.35) / 0.5 * math.pi).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 + (attackT - 0.35) * 2,
                    child: const Text('💢', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // JUGADOR (esquina inferior izquierda)
  // ---------------------------------------------------------------
  Widget _buildPlayer() {
    final attackT = _attack.value;
    final hitT = _hit.value;
    // Retrocede al recibir el ataque y da un saltito al acertar.
    final recoil = attackT > 0.4 && attackT < 1
        ? math.sin((attackT - 0.4) / 0.6 * math.pi * 3) * 6 * (1 - attackT)
        : 0.0;
    final hop = hitT > 0 && hitT < 0.5 ? -math.sin(hitT * 2 * math.pi) * 10 : 0.0;

    return Transform.translate(
      offset: Offset(recoil, hop),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WM.outline,
          border: Border.all(
            color: attackT > 0.4 && attackT < 0.9 ? const Color(0xFFFF4D5E) : WM.cyan,
            width: 3,
          ),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: PlayerAvatar(profile: widget.profile!, radius: 22),
      ),
    );
  }
}
