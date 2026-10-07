import 'package:flutter/foundation.dart';
import '../models/player_profile.dart';
import '../models/question.dart';
import '../models/level_config.dart';
import '../models/chapter_story.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import '../services/question_bank.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../services/cloud_service.dart';
import '../services/chapter_story_service.dart';

enum GameStatus { loading, playing, victory, defeat }

class GameController extends ChangeNotifier {
  final int worldId;
  final int chapterId;
  final int levelNumber;
  final bool isMiniChallenge;
  late final LevelConfig config = isMiniChallenge
      ? QuestionBank.getConfigForMiniChallenge(worldId, levelNumber)
      : QuestionBank.getConfigForLevel(worldId, chapterId, levelNumber);

  PlayerProfile? profile;
  List<Question> questions = [];
  int currentQuestionIndex = 0;
  late int playerHp = maxPlayerHp;
  late final int maxPlayerHp = isMiniChallenge || config.type == LevelType.worldBoss
      ? 4
      : 3;
  late int enemyHp = config.enemyHealth;

  int get enemyMaxHp => config.enemyHealth;

  GameStatus status = GameStatus.loading;
  bool isAnswered = false;
  int? selectedOptionIndex;
  final List<int> disabledOptionIndexes = [];
  int incorrectAnswersSinceMonsterAttack = 0;
  String? monsterReaction;

  int starsEarned = 1;
  late final int coinsReward = isMiniChallenge ? 15 : 50;
  late final int xpReward = isMiniChallenge ? 10 : 40;
  bool miniRewardGranted = false;
  ChapterStory? chapterStory;

  // 👈 Bandera para controlar si el controlador fue destruido y evitar fugas de memoria
  bool _isDisposed = false;

  GameController({
    required this.worldId,
    required this.chapterId,
    required this.levelNumber,
    this.isMiniChallenge = false,
  });

  @override
  void dispose() {
    _isDisposed = true; // 👈 Marcamos como destruido al salir de la pantalla
    super.dispose();
  }

  Question? get currentQuestion =>
      questions.isNotEmpty && currentQuestionIndex < questions.length
      ? questions[currentQuestionIndex]
      : null;

  Future<void> loadInitialData() async {
    status = GameStatus.loading;
    notifyListeners();

    profile = await SaveService.loadPlayerData();
    questions = isMiniChallenge
        ? QuestionBank.getQuestionsForMiniChallenge(worldId, levelNumber)
        : QuestionBank.getQuestionsForLevel(worldId, chapterId, levelNumber);

    if (_isDisposed) return; // 👈 Evitamos actualizar si ya se desmontó
    status = GameStatus.playing;
    notifyListeners();
  }

  void selectAnswer(int index, Function(String) onSnackBarMessage) {
    if (isAnswered ||
        questions.isEmpty ||
        disabledOptionIndexes.contains(index)) {
      return;
    }

    selectedOptionIndex = index;
    monsterReaction = null;
    isAnswered = true;
    notifyListeners();

    final question = currentQuestion;
    if (question == null) return;

    final isCorrect = (index == question.correctIndex);

    if (isCorrect) {
      AudioService.playSuccess();
      QuestService.incrementProgress('answer_trivia_10');
      // Los enemigos normales requieren dos aciertos, los guardianes tres y
      // los jefes finales cuatro. Así la dificultad del combate también crece.
      final hitsToDefeat = config.correctAnswersToDefeat;
      final damagePerAnswer = (enemyMaxHp / hitsToDefeat).ceil();
      enemyHp = (enemyHp - damagePerAnswer).clamp(0, enemyMaxHp).toInt();
    } else {
      AudioService.playDamage();
      playerHp--;
      incorrectAnswersSinceMonsterAttack++;
    }
    notifyListeners();
  }

  void continueAfterAnswer() {
    if (_isDisposed || !isAnswered || status != GameStatus.playing) return;

    if (playerHp <= 0) {
      _handleDefeat();
    } else if (enemyHp <= 0) {
      _handleVictory();
    } else if (incorrectAnswersSinceMonsterAttack >= 2) {
      _applyMonsterRewind();
    } else if (currentQuestionIndex + 1 < questions.length) {
      _nextQuestion();
    } else {
      _handleDefeat();
    }
  }

  void _applyMonsterRewind() {
    if (_isDisposed || questions.isEmpty) return;

    final failedQuestion = currentQuestion;
    if (failedQuestion == null) return;

    // Los jefes del mundo castigan con dos pasos de retroceso; los demás
    // monstruos hacen retroceder un paso cuando acumulas dos errores.
    final rewindSteps = config.type == LevelType.worldBoss ? 2 : 1;
    final targetIndex = (currentQuestionIndex - rewindSteps)
        .clamp(0, questions.length - 1)
        .toInt();
    final replacement = QuestionBank.getReplacementQuestion(
      original: failedQuestion,
      world: worldId,
      chapter: chapterId,
      level: levelNumber,
      isMiniChallenge: isMiniChallenge,
      usedQuestionIds: questions.map((question) => question.id).toSet(),
    );

    if (replacement != null) {
      questions[targetIndex] = replacement;
    }
    currentQuestionIndex = targetIndex;
    incorrectAnswersSinceMonsterAttack = 0;
    monsterReaction = replacement == null
        ? '¡El monstruo te hizo retroceder! Responde de nuevo para avanzar.'
        : '¡El monstruo te hizo retroceder! Nueva pregunta de ${replacement.category}.';
    isAnswered = false;
    selectedOptionIndex = null;
    disabledOptionIndexes.clear();
    notifyListeners();
  }

  void _nextQuestion() {
    if (_isDisposed) return;
    currentQuestionIndex++;
    isAnswered = false;
    selectedOptionIndex = null;
    disabledOptionIndexes.clear();
    notifyListeners();
  }

  void _handleVictory() async {
    if (_isDisposed) return;
    status = GameStatus.victory;
    AudioService.playVictorySound();

    if (!isMiniChallenge && levelNumber == 5) {
      final previousProgress = await SaveService.getStageProgress(
        worldId,
        chapterId,
        levelNumber,
      );
      if (previousProgress.stars == 0) {
        chapterStory = ChapterStoryService.afterChapter(worldId, chapterId);
      }
    }

    if (isMiniChallenge) {
      miniRewardGranted = await SaveService.claimMiniChallengeReward(
        'w${worldId}_challenge$levelNumber',
      );
      if (profile != null && miniRewardGranted) {
        profile!.coins += coinsReward;
        profile!.addExperience(xpReward);
        await SaveService.savePlayerData(profile!);
        QuestService.incrementProgress('win_battles_3');
        try {
          await CloudService.syncProfileToCloud(profile!);
        } catch (e) {
          debugPrint('No se pudo sincronizar la recompensa del mini-reto: $e');
        }
      }
      if (_isDisposed) return;
      notifyListeners();
      return;
    }

    QuestService.incrementProgress('win_battles_3');

    starsEarned = playerHp >= maxPlayerHp
        ? 3
        : playerHp == maxPlayerHp - 1
        ? 2
        : 1;

    // 1. Guardar Monedas y XP en el perfil local
    if (profile != null) {
      profile!.coins += coinsReward;
      profile!.addExperience(xpReward);
      await SaveService.savePlayerData(profile!);
    }

    // 2. Guardar las estrellas del nivel actual localmente
    StageProgress currentProgress = StageProgress(
      worldId: worldId,
      chapterId: chapterId,
      levelNumber: levelNumber,
      stars: starsEarned,
      isUnlocked: true,
    );
    await SaveService.saveStageProgress(currentProgress);

    // 3. Desbloquear el siguiente nivel
    int nextWorld = worldId;
    int nextChapter = chapterId;
    int nextLevel = levelNumber + 1;

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

    // 4. ☁️ SINCRONIZAR CON LA NUBE (Con manejo seguro de errores)
    if (profile != null) {
      try {
        await CloudService.syncProfileToCloud(profile!);
      } catch (e) {
        debugPrint(
          "⚠️ Advertencia: No se pudo sincronizar la victoria en la nube: $e",
        );
        // El juego local sigue intacto aunque falle el internet momentáneamente
      }
    }

    if (_isDisposed) return;
    notifyListeners();
  }

  void _handleDefeat() {
    if (_isDisposed) return;
    status = GameStatus.defeat;
    AudioService.playDamage();
    notifyListeners();
  }

  void usePotion(Function(String) showSnackBar) async {
    if (profile == null || _isDisposed) return;

    if (playerHp >= maxPlayerHp) {
      showSnackBar('¡Tu vida ya está al máximo!');
      return;
    }

    if (profile!.healthPotions <= 0) {
      showSnackBar('No tienes pociones disponibles. ¡Cómpralas en la tienda!');
      return;
    }

    profile!.healthPotions--;
    playerHp = (playerHp + 1).clamp(0, maxPlayerHp);
    AudioService.playPotionUse();

    if (_isDisposed) return;
    notifyListeners();

    await SaveService.savePlayerData(profile!);
    QuestService.incrementProgress('use_potion_2');
    showSnackBar('¡Has recuperado 1 vida!');
  }

  void useHint(Function(String) showSnackBar) async {
    if (profile == null || isAnswered || questions.isEmpty || _isDisposed) {
  return;
}

    if (profile!.letterHints <= 0) {
      showSnackBar('No tienes pistas disponibles. ¡Cómpralas en la tienda!');
      return;
    }

    final question = currentQuestion;
    if (question == null) return;

    List<int> incorrectIndexes = [];
    for (int i = 0; i < question.options.length; i++) {
      if (i != question.correctIndex && !disabledOptionIndexes.contains(i)) {
        incorrectIndexes.add(i);
      }
    }

    if (incorrectIndexes.isEmpty) {
      showSnackBar('No hay más opciones para descartar.');
      return;
    }

    incorrectIndexes.shuffle();
    int optionToDisable = incorrectIndexes.first;

    profile!.letterHints--;
    disabledOptionIndexes.add(optionToDisable);
    AudioService.playHintUse();

    if (_isDisposed) return;
    notifyListeners();

    await SaveService.savePlayerData(profile!);
    showSnackBar('¡Se ha descartado una opción incorrecta!');
  }
}
