import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/game_controller.dart';
import '../models/level_config.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/particle_explosion.dart';

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
        title: const Text(
          '¡VICTORIA ÉPICA!',
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
                      ? 'Recompensa de hoy ya obtenida'
                      : '+${_controller.coinsReward} Monedas',
                  style: GoogleFonts.poppins(
                    color: Colors.yellowAccent,
                    fontSize: 16,
                  ),
                ),
                if (!_controller.isMiniChallenge ||
                    _controller.miniRewardGranted)
                  Text(
                    '+${_controller.xpReward} XP',
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
              child: const Text(
                'CONTINUAR',
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
              'CONTINUAR',
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
              _showSnackBar('¡Has vuelto a la batalla con 1 vida!');
            } else {
              // Puede que no haya anuncio disponible o que el jugador
              // cerrara el video antes de terminar: no se da el premio.
              setDialogState(() {
                loadingAd = false;
                errorMessage =
                    'No se pudo completar el video. Inténtalo de nuevo o usa una poción.';
              });
            }
          }

          Future<void> onUsePotion() async {
            AudioService.playButtonClick();
            closeAndResume();
            final ok = await _controller.reviveWithPotion();
            if (mounted && ok) _showSnackBar('¡La poción te devolvió 1 vida!');
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
                  const OutlinedGameText(
                    '¡SIN VIDAS!',
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
                    '¿Quieres seguir luchando? Recupera 1 vida y continúa la batalla.',
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
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_circle_fill_rounded,
                                        color: Colors.white, size: 24),
                                    SizedBox(width: 8),
                                    OutlinedGameText('VER VIDEO', size: 18,
                                        font: GameFont.oswald),
                                    SizedBox(width: 8),
                                    // El emoji va fuera del texto con contorno
                                    // (si no, se dibujaría triplicado)
                                    Text('+1 ❤️', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Ya usaste el video en esta batalla.',
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
                            potions > 0 ? 'USAR POCIÓN ($potions)' : 'SIN POCIONES',
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
                      'Rendirse',
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
        title: const Text(
          '¡DERROTA!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Text(
          _controller.playerHp <= 0
              ? 'Te has quedado sin vidas. ¡Inténtalo de nuevo!'
              : 'El monstruo resistió tus respuestas. ¡Repasa y vuelve a intentarlo!',
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
              child: const Text(
                'REINTENTAR',
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
            backgroundColor: Color(0xFF0F0C29),
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        final currentQuestion = _controller.currentQuestion;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0C29),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              widget.isMiniChallenge
                  ? 'MINI-RETO ${widget.levelNumber}'
                  : 'COMBATE',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _isMuted ? Colors.redAccent : Colors.amber,
                ),
                onPressed: () {
                  AudioService.toggleMute();
                  setState(() {
                    _isMuted = AudioService.isMuted;
                  });
                },
              ),
              Row(
                children: List.generate(_controller.maxPlayerHp, (index) {
                  return Icon(
                    index < _controller.playerHp
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.redAccent,
                    size: 24,
                  );
                }),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _controller.config.backgroundAsset,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.62),
                colorBlendMode: BlendMode.darken,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66100B22), Color(0xCC0F0C29)],
                  ),
                ),
              ),
              SafeArea(
                child: currentQuestion == null
                ? const Center(
                    child: Text(
                      'No hay preguntas para esta fase.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildEnemyStatus(),
                        if (_controller.monsterReaction != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xCC5B1B35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.8),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.crisis_alert_rounded,
                                  color: Colors.orangeAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _controller.monsterReaction!,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PREGUNTA ${_controller.currentQuestionIndex + 1} DE ${_controller.questions.length}',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFD36B),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              'RETO ${currentQuestion.difficulty}/5',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF8FE9FF),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B4B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.purpleAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentQuestion.category.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF8FE9FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentQuestion.prompt,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView.builder(
                            itemCount:
                                currentQuestion.options.length +
                                (_controller.isAnswered ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == currentQuestion.options.length) {
                                final isCorrect =
                                    _controller.selectedOptionIndex ==
                                    currentQuestion.correctIndex;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF182B3A),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isCorrect
                                            ? const Color(0xFF71D57A)
                                            : const Color(0xFFFFC857),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isCorrect
                                              ? '¡Correcto!'
                                              : 'Respuesta correcta: ${currentQuestion.options[currentQuestion.correctIndex]}',
                                          style: GoogleFonts.poppins(
                                            color: isCorrect
                                                ? const Color(0xFF9AF2A0)
                                                : const Color(0xFFFFD980),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          currentQuestion.explanation.isNotEmpty
                                              ? currentQuestion.explanation
                                              : 'La opción correcta es “${currentQuestion.options[currentQuestion.correctIndex]}”.',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final isDisabled = _controller
                                  .disabledOptionIndexes
                                  .contains(index);

                              Color buttonColor = const Color(0xFF2E1065);
                              if (_controller.isAnswered) {
                                if (index == currentQuestion.correctIndex) {
                                  buttonColor = Colors.green;
                                } else if (index ==
                                    _controller.selectedOptionIndex) {
                                  buttonColor = Colors.red;
                                }
                              } else if (isDisabled) {
                                buttonColor = Colors.grey.shade800;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: buttonColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: isDisabled
                                      ? null
                                      : () => _controller.selectAnswer(
                                          index,
                                          _showSnackBar,
                                        ),
                                  child: Text(
                                    isDisabled
                                        ? '✖ Opción descartada'
                                        : currentQuestion.options[index],
                                    style: GoogleFonts.poppins(
                                      color: isDisabled
                                          ? Colors.white38
                                          : Colors.white,
                                      fontSize: 16,
                                      decoration: isDisabled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_controller.isAnswered)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: const Color(0xFF0F0C29),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: _controller.continueAfterAnswer,
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                _controller.playerHp <= 0
                                    ? 'VER RESULTADO'
                                    : 'CONTINUAR',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      (_controller.profile?.healthPotions ??
                                              0) >
                                          0
                                      ? Colors.redAccent.shade700
                                      : Colors.grey.shade700,
                                ),
                                onPressed: () =>
                                    _controller.usePotion(_showSnackBar),
                                icon: const Icon(
                                  Icons.local_hospital,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Poción (${_controller.profile?.healthPotions ?? 0})',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      (_controller.profile?.letterHints ?? 0) >
                                          0
                                      ? Colors.amber.shade700
                                      : Colors.grey.shade700,
                                ),
                                onPressed: () =>
                                    _controller.useHint(_showSnackBar),
                                icon: const Icon(
                                  Icons.lightbulb,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Pista (${_controller.profile?.letterHints ?? 0})',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnemyStatus() {
    final config = _controller.config;
    final difficultyLabel = switch (config.difficulty) {
      1 => 'Fácil',
      2 => 'Fácil+',
      3 => 'Media',
      4 => 'Difícil',
      _ => 'Épico',
    };
    final encounterLabel = config.isMiniChallenge
        ? 'MINI-RETO · $difficultyLabel'
        : config.type == LevelType.worldBoss
        ? 'JEFE DEL MUNDO · $difficultyLabel'
        : config.type == LevelType.miniBoss
        ? 'GUARDIÁN DEL CAPÍTULO · $difficultyLabel'
        : 'DIFICULTAD $difficultyLabel';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF211638),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 76,
            child: Image.asset(
              config.enemyAsset,
              fit: BoxFit.contain,
              cacheWidth: 256,
              errorBuilder: (_, _, _) => Text(
                config.enemyEmoji,
                style: const TextStyle(fontSize: 34),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  config.enemyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  encounterLabel,
                  style: GoogleFonts.poppins(
                    color: config.type == LevelType.worldBoss
                        ? Colors.orangeAccent
                        : Colors.cyanAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _controller.enemyHp / _controller.enemyMaxHp,
                    minHeight: 7,
                    backgroundColor: Colors.black45,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_controller.enemyHp}',
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
