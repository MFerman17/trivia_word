import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player_profile.dart';
import '../models/question.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import '../services/question_bank.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
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
  PlayerProfile? _profile;
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _playerHp = 3;
  final int _maxPlayerHp = 3;
  bool _isLoading = true;
  bool _isAnswered = false;
  int? _selectedOptionIndex;
  bool _triggerCoinRain = false;
  bool _isMuted = AudioService.isMuted;

  // Lista para rastrear qué opciones han sido descartadas por comodines
  final List<int> _disabledOptionIndexes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    AudioService.playBgm('game_bgm.mp3');

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _triggerCoinRain = true;
        });
      }
    });
  }

  @override
  void dispose() {
    AudioService.stopBgm();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    PlayerProfile profile = await SaveService.loadPlayerData();

    List<Question> questions = QuestionBank.getQuestionsForLevel(
      widget.worldId,
      widget.chapterId,
      widget.levelNumber,
    );

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _questions = questions;
      _isLoading = false;
    });
  }

  void _onAnswerSelected(int index) {
    if (_isAnswered ||
        _questions.isEmpty ||
        _disabledOptionIndexes.contains(index)) {
      return;
    }

    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;
    });

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = (index == currentQuestion.correctIndex);

    if (isCorrect) {
      AudioService.playSuccess();
      QuestService.incrementProgress('answer_trivia_10');
    } else {
      AudioService.playDamage();
      setState(() {
        _playerHp--;
      });
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      if (_playerHp <= 0) {
        _onDefeat();
      } else if (_currentQuestionIndex + 1 < _questions.length) {
        setState(() {
          _currentQuestionIndex++;
          _isAnswered = false;
          _selectedOptionIndex = null;
          _disabledOptionIndexes
              .clear(); // Limpiar opciones descartadas para la siguiente pregunta
        });
      } else {
        int stars = 1;
        if (_playerHp == 3) {
          stars = 3;
        } else if (_playerHp == 2) {
          stars = 2;
        }
        _onVictory(stars);
      }
    });
  }

  void _usePotion() async {
    if (_profile == null) return;

    if (_playerHp >= _maxPlayerHp) {
      _showSnackBar('¡Tu vida ya está al máximo!');
      return;
    }

    if (_profile!.healthPotions <= 0) {
      _showSnackBar('No tienes pociones disponibles. ¡Cómpralas en la tienda!');
      return;
    }

    setState(() {
      _profile!.healthPotions--;
      _playerHp = (_playerHp + 1).clamp(0, _maxPlayerHp);
    });

    AudioService.playPotionUse();
    await SaveService.savePlayerData(_profile!);
    QuestService.incrementProgress('use_potion_2');
    _showSnackBar('¡Has recuperado 1 vida!');
  }

  void _useHint() async {
    if (_profile == null || _isAnswered || _questions.isEmpty) return;

    if (_profile!.letterHints <= 0) {
      _showSnackBar('No tienes pistas disponibles. ¡Cómpralas en la tienda!');
      return;
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    // Buscar una opción incorrecta que aún no haya sido descartada
    List<int> incorrectIndexes = [];
    for (int i = 0; i < currentQuestion.options.length; i++) {
      if (i != currentQuestion.correctIndex &&
          !_disabledOptionIndexes.contains(i)) {
        incorrectIndexes.add(i);
      }
    }

    if (incorrectIndexes.isEmpty) {
      _showSnackBar('No hay más opciones para descartar.');
      return;
    }

    // Seleccionar una opción incorrecta al azar para descartar
    incorrectIndexes.shuffle();
    int optionToDisable = incorrectIndexes.first;

    setState(() {
      _profile!.letterHints--;
      _disabledOptionIndexes.add(optionToDisable);
    });

    AudioService.playHintUse();
    await SaveService.savePlayerData(_profile!);
    _showSnackBar('¡Se ha descartado una opción incorrecta!');
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

  void _onVictory(int starsEarned) async {
    await AudioService.stopBgm();
    AudioService.playVictorySound();
    QuestService.incrementProgress('win_battles_3');

    int coinsReward = 50;
    int xpReward = 40;

    if (_profile != null) {
      _profile!.coins += coinsReward;
      _profile!.addExperience(xpReward);
      _profile!.addStars(starsEarned);
      await SaveService.savePlayerData(_profile!);
    }

    StageProgress currentProgress = StageProgress(
      worldId: widget.worldId,
      chapterId: widget.chapterId,
      levelNumber: widget.levelNumber,
      stars: starsEarned,
      isUnlocked: true,
    );
    await SaveService.saveStageProgress(currentProgress);

    int nextWorld = widget.worldId;
    int nextChapter = widget.chapterId;
    int nextLevel = widget.levelNumber + 1;

    if (nextLevel > 5) {
      nextLevel = 1;
      nextChapter++;
      if (nextChapter > 3) {
        nextChapter = 1;
        nextWorld++;
      }
    }

    StageProgress nextProgress = StageProgress(
      worldId: nextWorld,
      chapterId: nextChapter,
      levelNumber: nextLevel,
      stars: 0,
      isUnlocked: true,
    );
    await SaveService.saveStageProgress(nextProgress);

    if (!mounted) return;

    setState(() {
      _triggerCoinRain = true;
    });

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
          trigger: _triggerCoinRain,
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
                  '+$coinsReward Monedas',
                  style: GoogleFonts.poppins(
                    color: Colors.yellowAccent,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '+$xpReward XP',
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
                      index < starsEarned ? Icons.star : Icons.star_border,
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

  void _onDefeat() {
    AudioService.stopBgm();
    AudioService.playDamage();

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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0C29),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final currentQuestion = _questions.isNotEmpty
        ? _questions[_currentQuestionIndex]
        : null;

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
              size: 26,
            ),
            tooltip: _isMuted ? 'Activar sonido' : 'Silenciar',
            onPressed: () {
              AudioService.toggleMute();
              setState(() {
                _isMuted = AudioService.isMuted;
              });
            },
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(_maxPlayerHp, (index) {
              return Icon(
                index < _playerHp ? Icons.favorite : Icons.favorite_border,
                color: Colors.redAccent,
                size: 26,
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
                          final isDisabled = _disabledOptionIndexes.contains(
                            index,
                          );

                          Color buttonColor = const Color(0xFF2E1065);
                          if (_isAnswered) {
                            if (index == currentQuestion.correctIndex) {
                              buttonColor = Colors.green;
                            } else if (index == _selectedOptionIndex) {
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
                                  : () => _onAnswerSelected(index),
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
                            backgroundColor: (_profile?.healthPotions ?? 0) > 0
                                ? Colors.redAccent.shade700
                                : Colors.grey.shade700,
                          ),
                          onPressed: _usePotion,
                          icon: const Icon(
                            Icons.local_hospital,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Poción (${_profile?.healthPotions ?? 0})',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_profile?.letterHints ?? 0) > 0
                                ? Colors.amber.shade700
                                : Colors.grey.shade700,
                          ),
                          onPressed: _useHint,
                          icon: const Icon(
                            Icons.lightbulb,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Pista (${_profile?.letterHints ?? 0})',
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
  }
}
