import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/fight_controller.dart';
import '../models/question.dart';
import '../services/audio_service.dart';
import '../services/fighter_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/monster_poses.dart';
import '../widgets/player_avatar.dart';
import 'shop_screen.dart';
import '../l10n/l10n.dart';

/// Pelea tipo "Street Fighter": el avatar del jugador contra el monstruo,
/// en vista lateral, al mejor de 3 rounds. Las preguntas son los golpes.
///
/// La lógica (vida, rounds, reloj, premios) está en [FightController];
/// esta pantalla solo dibuja y anima lo que el controlador decide.
class FightScreen extends StatefulWidget {
  const FightScreen({
    super.key,
    required this.worldId,
    required this.chapterId,
    required this.levelNumber,
  });

  final int worldId;
  final int chapterId;
  final int levelNumber;

  @override
  State<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends State<FightScreen> with TickerProviderStateMixin {
  late final FightController _fight = FightController(
    worldId: widget.worldId,
    chapterId: widget.chapterId,
    levelNumber: widget.levelNumber,
  );

  /// Movimiento de reposo de los dos luchadores (respiran y se balancean).
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  /// Animación de cada golpe (se reinicia con cada acción nueva).
  late final AnimationController _strike = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  int _seenActionId = 0;
  bool _endDialogShown = false;
  bool _posesCached = false;

  @override
  void initState() {
    super.initState();
    _fight.addListener(_onFightUpdate);
    _fight.load();
  }

  @override
  void dispose() {
    _fight.removeListener(_onFightUpdate);
    _fight.dispose();
    _idle.dispose();
    _strike.dispose();
    super.dispose();
  }

  void _onFightUpdate() {
    _precachePoses();
    if (_fight.actionId != _seenActionId) {
      _seenActionId = _fight.actionId;
      _strike.forward(from: 0);
    }
    if (_endDialogShown) return;
    if (_fight.phase == FightPhase.victory && _fight.resultReady) {
      _endDialogShown = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showVictoryDialog();
      });
    } else if (_fight.phase == FightPhase.defeat) {
      _endDialogShown = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showDefeatDialog();
      });
    }
  }

  /// Carga las 5 poses en memoria al empezar, para que al cambiar de pose
  /// no se vea un parpadeo mientras se lee la imagen.
  void _precachePoses() {
    final id = _fight.profile?.avatarCharacterId;
    if (_posesCached || id == null) return;
    _posesCached = true;
    for (final pose in PlayerAvatar.fighterPoses) {
      precacheImage(
        AssetImage(PlayerAvatar.fighterAssetFor(id, pose: pose)),
        context,
        onError: (_, _) {}, // Si falta una pose, se usa la de reserva.
      );
    }
    for (final pose in MonsterPoses.poses) {
      precacheImage(
        AssetImage(MonsterPoses.assetFor(_fight.config.enemyAsset, pose)),
        context,
        onError: (_, _) {},
      );
    }
  }

  /// Pose del monstruo: la contraria a la del jugador en cada momento.
  String _enemyPose({
    required double t,
    required bool active,
    required bool playerAttacks,
    required bool enemyAttacks,
  }) {
    switch (_fight.phase) {
      case FightPhase.victory:
        return 'lose';
      case FightPhase.defeat:
        return 'win';
      case FightPhase.roundEnd:
        return _fight.enemyHp <= 0 ? 'lose' : 'win';
      default:
        if (active && enemyAttacks && t < 0.75) return 'attack';
        if (active && playerAttacks && t > 0.2 && t < 0.85) return 'hit';
        return 'idle';
    }
  }

  /// Qué pose muestra el avatar en cada momento de la pelea.
  String _playerPose({
    required double t,
    required bool active,
    required bool playerAttacks,
    required bool enemyAttacks,
  }) {
    switch (_fight.phase) {
      case FightPhase.victory:
        return 'win';
      case FightPhase.defeat:
        return 'lose';
      case FightPhase.roundEnd:
        return _fight.enemyHp <= 0 ? 'win' : 'lose';
      default:
        // Golpea durante la embestida; recibe cuando le llega el golpe.
        if (active && playerAttacks && t < 0.75) return 'attack';
        if (active && enemyAttacks && t > 0.2 && t < 0.85) return 'hit';
        return 'idle';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _fight,
      builder: (context, _) {
        if (_fight.phase == FightPhase.loading) {
          return const Scaffold(
            backgroundColor: WM.outline,
            body: Center(child: CircularProgressIndicator(color: WM.cyan)),
          );
        }
        return Scaffold(
          backgroundColor: WM.outline,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _fight.config.backgroundAsset,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: _fight.isEnraged ? 0.35 : 0.45),
                colorBlendMode: BlendMode.darken,
              ),
              // En el round de furia, el escenario se tiñe de rojo.
              if (_fight.isEnraged)
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x33FF2D4A)),
                ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHud(),
                    Expanded(child: _buildStage()),
                    _buildControls(),
                  ],
                ),
              ),
              _buildOverlay(),
            ],
          ),
        );
      },
    );
  }

  // =================================================================
  // HUD: retratos, barras de vida enfrentadas, reloj y rounds
  // =================================================================
  Widget _buildHud() {
    final profile = _fight.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile != null) PlayerAvatar(profile: profile, radius: 20),
          const SizedBox(width: 4),
          Expanded(
            child: _fighterBar(
              name: profile?.name ?? context.l10n.you,
              hp: _fight.playerHp,
              maxHp: _fight.playerMaxHp,
              rounds: _fight.playerRounds,
              alignRight: false,
            ),
          ),
          _buildTimer(),
          Expanded(
            child: _fighterBar(
              name: _fight.config.enemyName,
              hp: _fight.enemyHp,
              maxHp: _fight.enemyMaxHp,
              rounds: _fight.enemyRounds,
              alignRight: true,
            ),
          ),
          const SizedBox(width: 4),
          Socket3D(
            size: 44,
            color: _fight.isFinal ? const Color(0xFFFF8A3D) : WM.violet,
            child: ClipOval(
              child: Image.asset(
                _fight.config.enemyAsset,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                cacheWidth: 128,
                errorBuilder: (_, _, _) => Text(_fight.config.enemyEmoji),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de vida estilo arcade. La del monstruo se vacía hacia la derecha,
  /// como en los juegos de lucha (las dos barras "miran" al centro).
  Widget _fighterBar({
    required String name,
    required int hp,
    required int maxHp,
    required int rounds,
    required bool alignRight,
  }) {
    final ratio = maxHp == 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    final color = ratio > 0.5
        ? const Color(0xFFFFD23C)
        : ratio > 0.25
            ? const Color(0xFFFF8A3D)
            : const Color(0xFFFF4D5E);
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF05010F),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: WM.outline, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: ratio),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
                widthFactor: value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [shade(color, 0.3), color, shade(color, -0.25)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignRight) ..._roundMarks(rounds),
            Flexible(
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anton(
                  color: WM.bone,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  shadows: const [Shadow(color: WM.outline, blurRadius: 2, offset: Offset(0, 1.5))],
                ),
              ),
            ),
            if (!alignRight) ..._roundMarks(rounds),
          ],
        ),
      ],
    );
  }

  /// Bolitas de rounds ganados (al mejor de 3 → 2 bolitas).
  List<Widget> _roundMarks(int won) => [
        const SizedBox(width: 4),
        for (var i = 0; i < _fight.rules.roundsToWin; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < won ? WM.gold : const Color(0xFF241A4C),
              border: Border.all(color: WM.outline, width: 1.5),
            ),
          ),
        const SizedBox(width: 4),
      ];

  Widget _buildTimer() {
    final showing = _fight.phase == FightPhase.question;
    final seconds = showing ? _fight.timeLeft.ceil() : _fight.secondsPerQuestion;
    final urgent = showing && _fight.timeFraction < 0.34;
    return Container(
      width: 46,
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: WM.outline,
        border: Border.all(color: urgent ? const Color(0xFFFF4D5E) : WM.gold, width: 3),
        boxShadow: [
          BoxShadow(
            color: (urgent ? const Color(0xFFFF4D5E) : WM.gold).withValues(alpha: 0.4),
            blurRadius: 10,
          ),
        ],
      ),
      child: OutlinedGameText(
        '$seconds',
        size: 22,
        colors: urgent
            ? const [Color(0xFFFFC2C8), Color(0xFFFF4D5E)]
            : const [Colors.white, WM.gold],
      ),
    );
  }

  // =================================================================
  // ESCENARIO: los dos luchadores frente a frente
  // =================================================================
  Widget _buildStage() {
    return LayoutBuilder(
      builder: (context, box) {
        final fighterHeight = math.min(box.maxHeight * 0.88, 240.0);
        return AnimatedBuilder(
          animation: Listenable.merge([_idle, _strike]),
          builder: (context, _) {
            final t = _strike.value;
            final action = _fight.lastAction;
            final playerAttacks = action == FightAction.punch ||
                action == FightAction.kick ||
                action == FightAction.special;
            final enemyAttacks =
                action == FightAction.enemyHit || action == FightAction.timeout;
            final active = t > 0 && t < 1;

            // Curva de embestida: va rápido hacia delante y vuelve.
            final lunge = !active
                ? 0.0
                : t < 0.3
                    ? Curves.easeOut.transform(t / 0.3)
                    : 1 - Curves.easeIn.transform(((t - 0.3) / 0.7).clamp(0.0, 1.0));
            // Retroceso de quien recibe el golpe (empieza al llegar el golpe).
            final recoil = !active || t < 0.25
                ? 0.0
                : math.sin(((t - 0.25) / 0.75) * math.pi) * (1 - t);
            // Temblor de pantalla en los golpes fuertes.
            final strong = action == FightAction.kick || action == FightAction.special || enemyAttacks;
            final quake = active && strong && t > 0.25 && t < 0.6
                ? math.sin(t * 70) * 6
                : 0.0;

            final idleT = _idle.value * 2 * math.pi;
            final reach = box.maxWidth * 0.22;

            final double playerDx = (playerAttacks ? lunge * reach : 0.0) -
                (enemyAttacks ? recoil * 30 : 0.0);
            final double enemyDx = -(enemyAttacks ? lunge * reach : 0.0) +
                (playerAttacks ? recoil * 34 : 0.0);

            return Transform.translate(
              offset: Offset(quake, 0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Suelo: franja con brillo para dar profundidad.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    height: 34,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: RadialGradient(
                          radius: 2.2,
                          colors: [
                            (_fight.isFinal ? const Color(0xFFFF8A3D) : WM.cyan)
                                .withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Jugador (izquierda).
                  Positioned(
                    left: box.maxWidth * 0.02,
                    bottom: 14,
                    child: Transform.translate(
                      offset: Offset(playerDx, math.sin(idleT) * 3),
                      child: _fighterSprite(
                        height: fighterHeight,
                        isPlayer: true,
                        hurt: enemyAttacks && active && t > 0.25 && t < 0.7,
                        // La pose de ataque ya se inclina: aquí solo un poco más.
                        tilt: playerAttacks ? lunge * (action == FightAction.kick ? 0.06 : 0.03) : 0,
                        glow: action == FightAction.special && active,
                        pose: _playerPose(
                          t: t,
                          active: active,
                          playerAttacks: playerAttacks,
                          enemyAttacks: enemyAttacks,
                        ),
                        // "Aplastar y estirar": se estira al golpear y se
                        // encoge al recibir, como en los dibujos animados.
                        squash: !active
                            ? 0.0
                            : playerAttacks
                                ? math.sin((t / 0.35).clamp(0.0, 1.0) * math.pi) * 0.07
                                : enemyAttacks && t > 0.2
                                    ? -math.sin(((t - 0.2) / 0.4).clamp(0.0, 1.0) * math.pi) * 0.06
                                    : 0.0,
                      ),
                    ),
                  ),
                  // Monstruo (derecha).
                  Positioned(
                    right: box.maxWidth * 0.02,
                    bottom: 14,
                    child: Transform.translate(
                      offset: Offset(enemyDx, math.cos(idleT) * 4),
                      child: _fighterSprite(
                        height: fighterHeight * (_fight.isFinal ? 1.12 : 1.0),
                        isPlayer: false,
                        hurt: playerAttacks && active && t > 0.25 && t < 0.7,
                        tilt: enemyAttacks ? -lunge * 0.06 : 0,
                        glow: _fight.isEnraged,
                        pose: _enemyPose(
                          t: t,
                          active: active,
                          playerAttacks: playerAttacks,
                          enemyAttacks: enemyAttacks,
                        ),
                        squash: !active
                            ? 0.0
                            : enemyAttacks
                                ? math.sin((t / 0.35).clamp(0.0, 1.0) * math.pi) * 0.07
                                : playerAttacks && t > 0.2
                                    ? -math.sin(((t - 0.2) / 0.4).clamp(0.0, 1.0) * math.pi) * 0.06
                                    : 0.0,
                      ),
                    ),
                  ),
                  // Impacto y número de daño sobre quien recibe.
                  if (active && t > 0.22) ..._impactEffects(box, t, playerAttacks),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _fighterSprite({
    required double height,
    required bool isPlayer,
    required bool hurt,
    required double tilt,
    required bool glow,
    String pose = 'idle',
    double squash = 0,
  }) {
    final profile = _fight.profile;
    final asset = isPlayer
        ? PlayerAvatar.fighterAssetFor(profile?.avatarCharacterId ?? 'explorador', pose: pose)
        : MonsterPoses.assetFor(_fight.config.enemyAsset, pose);

    Widget image = Image.asset(
      asset,
      key: ValueKey(asset),
      height: height,
      fit: BoxFit.contain,
      cacheHeight: 768,
      gaplessPlayback: true,
      // Si falta la pose: el jugador usa el aventurero de la portada y el
      // monstruo su imagen normal.
      errorBuilder: (_, _, _) => isPlayer
          ? Image.asset('assets/images/adventurer.png', height: height, fit: BoxFit.contain)
          : Image.asset(
              _fight.config.enemyAsset,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Text(_fight.config.enemyEmoji, style: TextStyle(fontSize: height * 0.5)),
            ),
    );

    // Cambio de pose con un fundido muy corto (90 ms): se nota el
    // movimiento sin que parezca un salto brusco entre dibujos.
    image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 90),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previous, ?current],
      ),
      child: image,
    );

    // Destello rojo al recibir el golpe (solo sobre la silueta).
    image = ColorFiltered(
      colorFilter: ColorFilter.mode(
        hurt ? const Color(0xAAFF2D4A) : Colors.transparent,
        BlendMode.srcATop,
      ),
      child: image,
    );

    return SizedBox(
      width: height * 0.85,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Sombra en el suelo.
          Container(
            width: height * 0.55,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          if (glow)
            Container(
              width: height * 0.8,
              height: height * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isPlayer ? WM.cyan : const Color(0xFFFF4D5E)).withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                // Se miran el uno al otro. Las poses ya están de perfil,
                // así que solo se giran un poco.
                ..rotateY(isPlayer ? 0.08 : -0.12)
                ..rotateZ(tilt)
                ..scaleByDouble(1 - squash * 0.6, 1 + squash, 1, 1),
              child: image,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _impactEffects(BoxConstraints box, double t, bool onEnemy) {
    final x = onEnemy ? box.maxWidth * 0.62 : box.maxWidth * 0.12;
    final special = _fight.lastAction == FightAction.special;
    return [
      // Chispazo del golpe (el emoji va fuera del texto con contorno).
      Positioned(
        left: x,
        bottom: box.maxHeight * 0.45,
        child: Opacity(
          opacity: (1 - (t - 0.22) / 0.5).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + (t - 0.22) * (special ? 4 : 2.4),
            child: Text(special ? '🌟' : '💥', style: const TextStyle(fontSize: 48)),
          ),
        ),
      ),
      // Daño que sale volando.
      if (_fight.lastDamage > 0)
        Positioned(
          left: x,
          bottom: box.maxHeight * 0.55 + 60 * t,
          child: Opacity(
            opacity: (1.2 - t).clamp(0.0, 1.0),
            child: OutlinedGameText(
              '-${_fight.lastDamage}',
              size: special ? 40 : 32,
              colors: onEnemy
                  ? const [Color(0xFFFFF1B0), Color(0xFFFFB627)]
                  : const [Color(0xFFFFC2C8), Color(0xFFFF4D5E)],
            ),
          ),
        ),
    ];
  }

  // =================================================================
  // CONTROLES: pregunta, 4 respuestas en cuadrícula y acciones
  // =================================================================
  Widget _buildControls() {
    final q = _fight.question;
    final inQuestion = _fight.phase == FightPhase.question;
    final inFeedback = _fight.phase == FightPhase.feedback;
    final showQuestion = q != null && (inQuestion || inFeedback);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEE160E36), Color(0xFF0D0326)],
        ),
        border: const Border(top: BorderSide(color: WM.cyan, width: 2)),
        boxShadow: [BoxShadow(color: WM.cyan.withValues(alpha: 0.25), blurRadius: 14)],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: !showQuestion
            ? const SizedBox(height: 120, width: double.infinity)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reloj como barra que se vacía.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: inQuestion ? _fight.timeFraction : 0,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF241A4C),
                      color: _fight.timeFraction < 0.34 ? const Color(0xFFFF4D5E) : WM.gold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.prompt,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAnswerGrid(q, inQuestion),
                  const SizedBox(height: 10),
                  _buildActionRow(inQuestion),
                ],
              ),
      ),
    );
  }

  Widget _buildAnswerGrid(Question q, bool enabled) {
    Widget cell(int i) {
      final disabled = _fight.disabledOptions.contains(i);
      final reveal = !enabled; // se está viendo el resultado
      Color done = const Color(0xFF3A3452);
      if (reveal && i == q.correctIndex) done = const Color(0xFF2FC22A);
      if (reveal && i == _fight.selectedIndex && i != q.correctIndex) {
        done = const Color(0xFFE0344A);
      }
      return Pressable3D(
        onTap: enabled && !disabled ? () => _fight.answer(i) : null,
        color: const Color(0xFF5B3FC4),
        disabledColor: done,
        height: 46,
        depth: 5,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          disabled ? '—' : q.options[i],
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.oswald(
            color: disabled || (reveal && i != q.correctIndex && i != _fight.selectedIndex)
                ? Colors.white38
                : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.1,
            shadows: const [Shadow(color: WM.outline, blurRadius: 2, offset: Offset(0, 1.5))],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: row * 2 + col < q.options.length
                      ? cell(row * 2 + col)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow(bool enabled) {
    final potions = _fight.profile?.healthPotions ?? 0;
    final hints = _fight.profile?.letterHints ?? 0;
    return Row(
      children: [
        Expanded(
          child: _smallAction(
            emoji: '🧪',
            label: '$potions',
            color: const Color(0xFFE0344A),
            onTap: enabled && potions > 0 && _fight.playerHp < _fight.playerMaxHp
                ? _fight.usePotion
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _smallAction(
            emoji: '💡',
            label: '$hints',
            color: const Color(0xFFFF9D00),
            onTap: enabled && hints > 0 ? _fight.useHint : null,
          ),
        ),
        const SizedBox(width: 8),
        // Barra de SUPER: se llena con los aciertos; llena, se pulsa.
        Expanded(flex: 2, child: _buildSuperButton(enabled)),
      ],
    );
  }

  Widget _smallAction({
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Pressable3D(
      onTap: onTap,
      color: color,
      height: 36,
      depth: 4,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 4),
          OutlinedGameText(label, size: 15, font: GameFont.oswald),
        ],
      ),
    );
  }

  Widget _buildSuperButton(bool enabled) {
    final ready = _fight.superReady && enabled;
    final button = Pressable3D(
      onTap: ready ? _fight.useSuper : null,
      color: const Color(0xFF00B8FF),
      disabledColor: const Color(0xFF241A4C),
      height: 36,
      depth: 4,
      padding: EdgeInsets.zero,
      // StackFit.expand: el relleno ocupa todo el botón, no solo el texto.
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Relleno que muestra cuánto falta.
          if (!_fight.superReady)
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _fight.superMeter,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B8FF).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 4),
              OutlinedGameText(
                _fight.superReady ? context.l10n.superReady : context.l10n.superLabel,
                size: 15,
                font: GameFont.oswald,
              ),
            ],
          ),
        ],
      ),
    );
    return ready ? Pulse(amount: 0.08, child: button) : button;
  }

  // =================================================================
  // CARTELES: ROUND / ¡PELEA! / K.O. / texto del golpe
  // =================================================================
  Widget _buildOverlay() {
    String big;
    String small;
    List<Color> colors = const [Colors.white, WM.gold];

    switch (_fight.phase) {
      case FightPhase.roundIntro:
        final isLast = _fight.playerRounds == 1 && _fight.enemyRounds == 1;
        big = isLast ? context.l10n.roundFinal : context.l10n.roundNumber(_fight.round);
        small = _fight.isEnraged ? context.l10n.monsterEnraged : context.l10n.fight;
      case FightPhase.roundEnd:
        big = 'K.O.';
        small = _fight.enemyHp <= 0 ? context.l10n.roundWon : context.l10n.roundLost;
        colors = _fight.enemyHp <= 0
            ? const [Color(0xFFFFF1B0), WM.gold]
            : const [Color(0xFFFFC2C8), Color(0xFFFF4D5E)];
      case FightPhase.feedback:
        // Nombre del golpe, pequeño, sobre el escenario.
        return Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_fight.actionId),
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.elasticOut,
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: OutlinedGameText(
                  _fight.actionLabel,
                  size: 26,
                  letterSpacing: 1.5,
                  colors: _fight.lastAction == FightAction.enemyHit ||
                          _fight.lastAction == FightAction.timeout
                      ? const [Color(0xFFFFC2C8), Color(0xFFFF4D5E)]
                      : const [Color(0xFFFFF1B0), WM.gold],
                ),
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('${_fight.phase}-${_fight.round}'),
              tween: Tween(begin: 2.2, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, s, child) => Transform.scale(scale: s, child: child),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedGameText(big, size: 58, letterSpacing: 3, colors: colors),
                  const SizedBox(height: 6),
                  OutlinedGameText(small, size: 24, font: GameFont.oswald, letterSpacing: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =================================================================
  // FIN DE LA PELEA
  // =================================================================
  void _showVictoryDialog() {
    final f = _fight;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Panel3D(
          accent: WM.gold,
          glow: 0.7,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedGameText(
                f.isFinal ? context.l10n.worldCleared : context.l10n.victory,
                size: 30,
                letterSpacing: 2,
                colors: const [Color(0xFFFFF1B0), WM.gold],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 500 + i * 300),
                      curve: Curves.elasticOut,
                      builder: (context, s, child) => Transform.scale(scale: s, child: child),
                      child: Icon(
                        i < f.starsEarned ? Icons.star_rounded : Icons.star_border_rounded,
                        color: i < f.starsEarned ? WM.gold : Colors.white30,
                        size: 46,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                f.enemyRounds == 0 ? context.l10n.flawlessWin : context.l10n.won21,
                style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
              ),
              if (f.bestCombo >= 3)
                Text(
                  context.l10n.bestCombo(f.bestCombo),
                  style: GoogleFonts.oswald(color: WM.cyan, fontSize: 13),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Chip3D(emoji: '🪙', text: '+${f.coinsEarned}', accent: WM.gold),
                  Chip3D(emoji: '✨', text: '+${f.xpEarned} XP', accent: WM.cyan),
                  if (f.gemsEarned > 0)
                    Chip3D(emoji: '💎', text: '+${f.gemsEarned}', accent: WM.violet),
                ],
              ),
              if (!f.firstWin) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.reducedReward,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.oswald(color: Colors.white38, fontSize: 12),
                ),
              ],
              if (f.chapterStory != null) ...[
                const SizedBox(height: 14),
                Text(
                  f.chapterStory!.heading,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.metalMania(color: WM.gold, fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  f.chapterStory!.narrative,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13, height: 1.3),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Pressable3D(
                  onTap: () {
                    AudioService.playButtonClick();
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                  },
                  color: WM.gold,
                  height: 50,
                  child: OutlinedGameText(context.l10n.continueButton, size: 18, font: GameFont.oswald),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDefeatDialog() {
    const danger = Color(0xFFFF4D5E);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Panel3D(
          accent: danger,
          glow: 0.5,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedGameText(
                context.l10n.defeat,
                size: 32,
                letterSpacing: 2,
                colors: const [Color(0xFFFFB3BA), danger],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.fightDefeatTip,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Pressable3D(
                  onTap: () {
                    AudioService.playButtonClick();
                    Navigator.of(dialogContext).pop();
                    _restart();
                  },
                  color: danger,
                  height: 48,
                  child: OutlinedGameText(context.l10n.rematch, size: 18, font: GameFont.oswald),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Pressable3D(
                  onTap: () async {
                    AudioService.playButtonClick();
                    Navigator.of(dialogContext).pop();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopScreen(
                          playerProfile: _fight.profile,
                          initialTab: ShopScreen.fighterTab,
                        ),
                      ),
                    );
                    if (mounted) Navigator.of(context).pop();
                  },
                  color: WM.cyan,
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👊', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      OutlinedGameText(context.l10n.upgradeFighter, size: 16, font: GameFont.oswald),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  AudioService.playButtonClick();
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop();
                },
                child: Text(
                  context.l10n.backToMap,
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
      ),
    );
  }

  /// Revancha: se vuelve a abrir la pelea desde cero.
  void _restart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FightScreen(
          worldId: widget.worldId,
          chapterId: widget.chapterId,
          levelNumber: widget.levelNumber,
        ),
      ),
    );
  }
}

/// Reglas de entrada que muestra el mapa antes de una pelea.
class FightGate {
  FightGate._();

  /// Cuántas estrellas faltan para poder entrar (0 = puede entrar).
  static int missingStars({required int chapter, required int starsInWorld}) =>
      math.max(0, FighterService.starsRequired(chapter) - starsInWorld);
}
