import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/game_controller.dart';
import '../services/audio_service.dart';
import '../widgets/particle_explosion.dart';

class GameScreen extends StatefulWidget {
  final int worldId;
  final int chapterId;
  final int levelNumber;

  const GameScreen({
    super.key,
    this.worldId = 1,
    this.chapterId = 1,
    this.levelNumber = 1,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _controller;
  bool _isMuted = AudioService.isMuted;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      worldId: widget.worldId,
      chapterId: widget.chapterId,
      levelNumber: widget.levelNumber,
    );
    _controller.addListener(_onControllerUpdate);
    _controller.loadInitialData();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (_controller.status == GameStatus.victory) {
      _showVictoryDialog();
    } else if (_controller.status == GameStatus.defeat) {
      _showDefeatDialog();
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
                  '+${_controller.coinsReward} Monedas',
                  style: GoogleFonts.poppins(
                    color: Colors.yellowAccent,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '+${_controller.xpReward} XP',
                  style: GoogleFonts.poppins(
                    color: Colors.cyanAccent,
                    fontSize: 16,
                  ),
                ),
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
            ),
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () {
                AudioService.playButtonClick();
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
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
        content: const Text(
          'Te has quedado sin vidas. ¡Inténtalo de nuevo!',
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
            body: Center(
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          );
        }

        final currentQuestion = _controller.currentQuestion;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0C29),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Fase ${widget.worldId}.${widget.chapterId}.${widget.levelNumber}',
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
          body: SafeArea(
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
                          child: Text(
                            currentQuestion.prompt,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView.builder(
                            itemCount: currentQuestion.options.length,
                            itemBuilder: (context, index) {
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (_controller.profile?.healthPotions ?? 0) > 0
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
                                    (_controller.profile?.letterHints ?? 0) > 0
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
        );
      },
    );
  }
}