import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/game_controller.dart';
import '../models/level_config.dart';
import '../models/question.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../widgets/battle_arena.dart';
import '../widgets/game_3d.dart';
import '../widgets/particle_explosion.dart';
import '../l10n/l10n.dart';
import '../services/cheer_service.dart';

class GameScreen extends StatefulWidget {
  final int worldId;
  final int chapterId;
  final int levelNumber;
  final bool isMiniChallenge;

  const GameScreen({
    super.key,
    this.worldId = 1,
    this.chapterId = 1,
    this.levelNumber = 1,
    this.isMiniChallenge = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _controller;
  bool _isMuted = AudioService.isMuted;

  // Evita abrir dos diálogos de fin de partida a la vez: el controlador
  // avisa (notifyListeners) muchas veces, y cada aviso con el estado
  // "derrota" podía apilar otro diálogo encima.
  bool _endDialogOpen = false;

  // Contadores que avisan al escenario (BattleArena) de lo que pasó:
  // al subir, se lanza la animación de golpe o de ataque.
  int _hitCount = 0;
  int _attackCount = 0;
  int _lastDamage = 0;
  bool _wasAnswered = false;
  int _previousEnemyHp = 0;
  int _hpBeforeAnswer = 0;

  // Frase de ánimo de la última respuesta.
  String? _cheer;
  bool _cheerPositive = true;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      worldId: widget.worldId,
      chapterId: widget.chapterId,
      levelNumber: widget.levelNumber,
      isMiniChallenge: widget.isMiniChallenge,
    );
    _controller.addListener(_onControllerUpdate);
    _controller.loadInitialData();
    // Precarga un anuncio al empezar la batalla, para que si el jugador
    // pierde y quiere revivir, el video salga al instante y no tras varios
    // segundos de espera (justo cuando es más fácil que se rinda).
    AdService.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    _detectBattleEvents();
    if (_endDialogOpen) return;
    if (_controller.status == GameStatus.victory) {
      _endDialogOpen = true;
      _showVictoryDialog();
    } else if (_controller.status == GameStatus.defeat) {
      _endDialogOpen = true;
      if (_controller.canRevive) {
        _showReviveDialog();
      } else {
        _showDefeatDialog();
      }
    }
  }

  /// Mira qué cambió desde el último aviso del controlador: si se acaba de
  /// responder, decide si el monstruo recibe un golpe o ataca.
  void _detectBattleEvents() {
    final answered = _controller.isAnswered;
    final question = _controller.currentQuestion;
    if (answered && !_wasAnswered && question != null) {
      // El controlador avisa al marcar la respuesta y OTRA VEZ al restar la
      // vida al monstruo; por eso se guarda la vida de antes y el daño se
      // recalcula en cada aviso mientras la pregunta sigue respondida.
      _hpBeforeAnswer = _previousEnemyHp;
      if (_controller.selectedOptionIndex == question.correctIndex) {
        _hitCount++;
        _cheerPositive = true;
        _cheer = CheerService.next(correct: true);
      } else {
        _attackCount++;
        _cheerPositive = false;
        _cheer = CheerService.next(correct: false);
      }
    }
    if (answered) {
      _lastDamage = (_hpBeforeAnswer - _controller.enemyHp).clamp(0, 9999).toInt();
    } else {
      _previousEnemyHp = _controller.enemyHp;
    }
    _wasAnswered = answered;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.indigo,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showVictoryDialog() {
    // Una campanilla por cada estrella ganada, después de la fanfarria.
    if (!_controller.isMiniChallenge) {
      for (var i = 0; i < _controller.starsEarned; i++) {
        Future.delayed(Duration(milliseconds: 1100 + i * 380), () {
          if (mounted) AudioService.playStar();
        });
      }
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: Text(
          context.l10n.epicVictory,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: ParticleExplosion(
          trigger: true,
          particleEmoji: '🪙',
          particleCount: 35,
          type: ExplosionType.rain,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1D36),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _controller.isMiniChallenge && !_controller.miniRewardGranted
                      ? context.l10n.dailyRewardTaken
                      : context.l10n.coinsReward(_controller.coinsReward),
                  style: GoogleFonts.poppins(
                    color: Colors.yellowAccent,
                    fontSize: 16,
                  ),
                ),
                if (!_controller.isMiniChallenge ||
                    _controller.miniRewardGranted)
                  Text(
                    context.l10n.xpReward(_controller.xpReward),
                    style: GoogleFonts.poppins(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                    ),
                  ),
                if (!_controller.isMiniChallenge) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Icon(
                        index < _controller.starsEarned
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () async {
                AudioService.playButtonClick();
                Navigator.of(dialogContext).pop();
                if (_controller.chapterStory != null) {
                  await Future<void>.delayed(
                    const Duration(milliseconds: 120),
                  );
                  if (!mounted) return;
                  await _showChapterStoryDialog();
                }
                if (mounted) Navigator.of(context).pop();
              },
              child: Text(
                context.l10n.continueButton,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChapterStoryDialog() async {
    final story = _controller.chapterStory;
    if (story == null || !mounted) return;

    AudioService.playPageFlip();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17132C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFFFC857), width: 2),
        ),
        title: Text(
          story.heading,
          textAlign: TextAlign.center,
          style: GoogleFonts.anton(
            color: const Color(0xFFFFD36B),
            fontSize: 23,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: Image.asset(
                    _controller.config.backgroundAsset,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.35),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                story.destination,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1EE3CF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                story.narrative,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                story.objective,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFD36B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC857),
              foregroundColor: const Color(0xFF17132C),
            ),
            onPressed: () {
              AudioService.playButtonClick();
              Navigator.of(dialogContext).pop();
            },
            icon: const Icon(Icons.auto_stories_rounded),
            label: Text(
              context.l10n.continueButton,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // ¿CONTINUAR? — se muestra al quedarse sin vidas
  // =================================================================

  /// Muestra el video recompensado. Devuelve true solo si se vio entero.
  ///
  /// Los anuncios de AdMob solo funcionan en Android. Para que puedas probar
  /// el flujo completo en Chrome mientras desarrollas, en modo debug (y fuera
  /// de Android) se simula un video de 1 segundo. En la versión publicada
  /// (kDebugMode = false) esta simulación nunca se ejecuta.
  Future<bool> _watchReviveAd() async {
    final adsSupported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!adsSupported && kDebugMode) {
      await Future<void>.delayed(const Duration(seconds: 1));
      return true;
    }
    return AdService.showRewardedAd();
  }

  void _showReviveDialog() {
    // Estas variables viven fuera del builder para conservar su valor
    // cada vez que el diálogo se redibuja con setDialogState.
    bool loadingAd = false;
    String? errorMessage;
    const Color danger = Color(0xFFFF4D5E);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final potions = _controller.profile?.healthPotions ?? 0;

          void closeAndResume() {
            _endDialogOpen = false;
            Navigator.of(dialogContext).pop();
          }

          Future<void> onWatchAd() async {
            AudioService.playButtonClick();
            setDialogState(() {
              loadingAd = true;
              errorMessage = null;
            });
            final earned = await _watchReviveAd();
            if (!mounted || !dialogContext.mounted) return;
            if (earned) {
              closeAndResume();
              _controller.reviveWithAd();
              _showSnackBar(context.l10n.backInBattle);
            } else {
              // Puede que no haya anuncio disponible o que el jugador
              // cerrara el video antes de terminar: no se da el premio.
              setDialogState(() {
                loadingAd = false;
                errorMessage =
                    context.l10n.videoFailed;
              });
            }
          }

          Future<void> onUsePotion() async {
            AudioService.playButtonClick();
            closeAndResume();
            final ok = await _controller.reviveWithPotion();
            if (mounted && ok) _showSnackBar(context.l10n.potionRevived);
          }

          void onGiveUp() {
            AudioService.playButtonClick();
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop();
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Panel3D(
              accent: danger,
              glow: 0.6,
              radius: 22,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedGameText(
                    context.l10n.outOfLives,
                    size: 30,
                    letterSpacing: 2,
                    colors: [Color(0xFFFFB3BA), danger],
                  ),
                  const SizedBox(height: 12),
                  const Bob(
                    amplitude: 5,
                    child: Socket3D(
                      size: 76,
                      color: danger,
                      child: Text('💔', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.keepFighting,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // --- Opción 1: video (la que monetiza, por eso va primero,
                  //     en dorado y latiendo) ---
                  if (_controller.canReviveWithAd)
                    SizedBox(
                      width: double.infinity,
                      child: Pulse(
                        amount: 0.04,
                        child: Pressable3D(
                          onTap: loadingAd ? null : onWatchAd,
                          color: WM.gold,
                          disabledColor: const Color(0xFF9A7A2A),
                          height: 54,
                          child: loadingAd
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: WM.outline,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_circle_fill_rounded,
                                        color: Colors.white, size: 24),
                                    const SizedBox(width: 8),
                                    OutlinedGameText(context.l10n.watchVideo, size: 18,
                                        font: GameFont.oswald),
                                    const SizedBox(width: 8),
                                    // El emoji va fuera del texto con contorno
                                    // (si no, se dibujaría triplicado)
                                    const Text('+1 ❤️', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        context.l10n.videoAlreadyUsed,
                        style: GoogleFonts.oswald(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // --- Opción 2: poción ---
                  SizedBox(
                    width: double.infinity,
                    child: Pressable3D(
                      onTap: _controller.canReviveWithPotion && !loadingAd
                          ? onUsePotion
                          : null,
                      color: WM.cyan,
                      height: 48,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🧪', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          OutlinedGameText(
                            potions > 0 ? context.l10n.usePotionCount(potions) : context.l10n.noPotions,
                            size: 16,
                            font: GameFont.oswald,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oswald(color: const Color(0xFFFFB3BA), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),

                  // --- Rendirse: discreto, para no competir con las otras ---
                  TextButton(
                    onPressed: loadingAd ? null : onGiveUp,
                    child: Text(
                      context.l10n.giveUp,
                      style: GoogleFonts.oswald(
                        color: Colors.white54,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDefeatDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: Text(
          context.l10n.defeatTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Text(
          _controller.playerHp <= 0
              ? context.l10n.defeatNoLives
              : context.l10n.defeatMonsterResisted,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                AudioService.playButtonClick();
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                context.l10n.retry,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.status == GameStatus.loading) {
          return const Scaffold(
            backgroundColor: WM.outline,
            body: Center(child: CircularProgressIndicator(color: WM.cyan)),
          );
        }

        final currentQuestion = _controller.currentQuestion;

        return Scaffold(
          backgroundColor: WM.outline,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Fondo del mundo, oscurecido para que destaquen monstruo y texto.
              Image.asset(
                _controller.config.backgroundAsset,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.darken,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.35, 1],
                    colors: [Color(0x33100B22), Color(0x66100B22), Color(0xEE0D0326)],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: currentQuestion == null
                          ? Center(
                              child: Text(
                                context.l10n.noQuestionsPhase,
                                style: GoogleFonts.oswald(color: Colors.white),
                              ),
                            )
                          : _buildBattle(currentQuestion),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // BARRA SUPERIOR: volver, título, sonido y vidas
  // ---------------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Pressable3D(
            onTap: () => Navigator.maybePop(context),
            color: const Color(0xFF3A2A7A),
            height: 38,
            depth: 5,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Icon(Icons.arrow_back_rounded, color: WM.bone, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedGameText(
              widget.isMiniChallenge
                  ? context.l10n.miniChallengeTitle(widget.levelNumber)
                  : context.l10n.battleTitle,
              size: 20,
              letterSpacing: 1.5,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _isMuted ? Colors.redAccent : WM.gold,
            ),
            onPressed: () {
              AudioService.toggleMute();
              setState(() => _isMuted = AudioService.isMuted);
            },
          ),
          // Vidas: el corazón que se pierde "late" al vaciarse.
          for (var i = 0; i < _controller.maxPlayerHp; i++)
            AnimatedScale(
              scale: i < _controller.playerHp ? 1 : 0.8,
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              child: Icon(
                i < _controller.playerHp ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: const Color(0xFFFF4D5E),
                size: 24,
                shadows: const [Shadow(color: WM.outline, blurRadius: 3, offset: Offset(0, 2))],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // COMBATE: escenario con el monstruo + pregunta + respuestas
  // ---------------------------------------------------------------
  Widget _buildBattle(Question currentQuestion) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          BattleArena(
            enemyAsset: _controller.config.enemyAsset,
            enemyEmoji: _controller.config.enemyEmoji,
            enemyName: _controller.config.enemyName,
            encounterLabel: _encounterLabel(),
            isBoss: _controller.isBossBattle,
            enemyHp: _controller.enemyHp,
            enemyMaxHp: _controller.enemyMaxHp,
            hitCount: _hitCount,
            attackCount: _attackCount,
            lastDamage: _lastDamage,
            // La frase se ve mientras se lee la explicación de la respuesta.
            cheer: _controller.isAnswered ? _cheer : null,
            cheerPositive: _cheerPositive,
            profile: _controller.profile,
            // Más bajo mientras se lee la explicación, para que quepa.
            compact: _controller.isAnswered,
          ),
          if (_controller.monsterReaction != null) ...[
            const SizedBox(height: 8),
            _buildMonsterReaction(),
          ],
          const SizedBox(height: 10),
          _buildQuestionCard(currentQuestion),
          const SizedBox(height: 12),
          Expanded(child: _buildAnswers(currentQuestion)),
          const SizedBox(height: 8),
          _buildBottomActions(),
        ],
      ),
    );
  }

  String _encounterLabel() {
    final config = _controller.config;
    final difficultyLabel = switch (config.difficulty) {
      1 => context.l10n.diffEasy,
      2 => context.l10n.diffEasyPlus,
      3 => context.l10n.diffMedium,
      4 => context.l10n.diffHard,
      _ => context.l10n.diffEpic,
    };
    if (config.isMiniChallenge) return context.l10n.encounterMini(difficultyLabel);
    if (config.type == LevelType.worldBoss) {
      return context.l10n.encounterWorldBoss(difficultyLabel);
    }
    if (config.type == LevelType.miniBoss) {
      return context.l10n.encounterGuardian(difficultyLabel);
    }
    return difficultyLabel;
  }

  Widget _buildMonsterReaction() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xDD5B1B35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WM.outline, width: 2.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.crisis_alert_rounded, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _controller.monsterReaction!,
              style: GoogleFonts.oswald(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question currentQuestion) {
    return Panel3D(
      accent: WM.violet,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                context.l10n.questionCounter(
                  _controller.currentQuestionIndex + 1,
                  _controller.questions.length,
                ),
                style: GoogleFonts.oswald(
                  color: WM.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  currentQuestion.category.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.oswald(
                    color: WM.cyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // La pregunta entra girando cada vez que cambia.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              currentQuestion.prompt,
              key: ValueKey(currentQuestion.id),
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswers(Question currentQuestion) {
    final options = currentQuestion.options;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (var index = 0; index < options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildAnswerButton(currentQuestion, index),
          ),
        if (_controller.isAnswered) _buildExplanation(currentQuestion),
      ],
    );
  }

  Widget _buildAnswerButton(Question question, int index) {
    final isDisabled = _controller.disabledOptionIndexes.contains(index);
    final answered = _controller.isAnswered;
    final isCorrect = index == question.correctIndex;
    final isSelected = index == _controller.selectedOptionIndex;

    // Colores: morado normal, verde la correcta, rojo la elegida si falló.
    const Color color = Color(0xFF5B3FC4);
    Color disabledColor = const Color(0xFF3A3452);
    if (answered && isCorrect) {
      disabledColor = const Color(0xFF2FC22A);
    } else if (answered && isSelected) {
      disabledColor = const Color(0xFFE0344A);
    }

    return Pressable3D(
      onTap: answered || isDisabled
          ? null
          : () => _controller.selectAnswer(index, _showSnackBar),
      color: color,
      disabledColor: disabledColor,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // Letra de la opción en un engaste pequeño.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: WM.outline.withValues(alpha: 0.55),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: answered && (isCorrect || isSelected)
                ? Icon(
                    isCorrect ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  )
                : Text(
                    String.fromCharCode(65 + index),
                    style: GoogleFonts.anton(color: WM.bone, fontSize: 14),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDisabled ? context.l10n.optionDiscarded : question.options[index],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.oswald(
                color: isDisabled || (answered && !isCorrect && !isSelected)
                    ? Colors.white38
                    : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: isDisabled ? TextDecoration.lineThrough : null,
                shadows: const [Shadow(color: WM.outline, blurRadius: 2, offset: Offset(0, 1.5))],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanation(Question question) {
    final isCorrect = _controller.selectedOptionIndex == question.correctIndex;
    final correctText = question.options[question.correctIndex];
    return EntranceFlip(
      index: 0,
      child: Panel3D(
        accent: isCorrect ? const Color(0xFF5BE37A) : WM.gold,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? context.l10n.correct : context.l10n.correctAnswerIs(correctText),
              style: GoogleFonts.oswald(
                color: isCorrect ? const Color(0xFF9AF2A0) : const Color(0xFFFFD980),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              question.explanation.isNotEmpty
                  ? question.explanation
                  : context.l10n.correctOptionIs(correctText),
              style: GoogleFonts.oswald(color: Colors.white, fontSize: 14, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_controller.isAnswered) {
      return SizedBox(
        width: double.infinity,
        child: Pulse(
          amount: 0.03,
          child: Pressable3D(
            onTap: _controller.continueAfterAnswer,
            color: WM.gold,
            height: 50,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedGameText(
                  _controller.playerHp <= 0 ? context.l10n.seeResult : context.l10n.continueButton,
                  size: 18,
                  font: GameFont.oswald,
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      );
    }

    final potions = _controller.profile?.healthPotions ?? 0;
    final hints = _controller.profile?.letterHints ?? 0;
    return Row(
      children: [
        Expanded(
          child: Pressable3D(
            onTap: () => _controller.usePotion(_showSnackBar),
            color: potions > 0 ? const Color(0xFFE0344A) : const Color(0xFF4A4660),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🧪', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                OutlinedGameText(context.l10n.potionCount(potions), size: 14, font: GameFont.oswald),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Pressable3D(
            onTap: () => _controller.useHint(_showSnackBar),
            color: hints > 0 ? const Color(0xFFFF9D00) : const Color(0xFF4A4660),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                OutlinedGameText(context.l10n.hintCount(hints), size: 14, font: GameFont.oswald),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
