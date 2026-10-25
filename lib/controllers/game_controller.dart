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
import '../services/lives_service.dart';

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
  /// Las vidas del combate son las vidas GLOBALES del jugador
  /// (LivesService): lo que se pierde aquí sigue perdido en el siguiente nivel.
  late int playerHp = LivesService.lives.value;
  final int maxPlayerHp = LivesService.maxLives;

  /// Fallos en este nivel: deciden las estrellas (0 = 3★, 1 = 2★, más = 1★).
  int mistakes = 0;
  late int enemyHp = config.enemyHealth;

  int get enemyMaxHp => config.enemyHealth;

  GameStatus status = GameStatus.loading;
  bool isAnswered = false;
  int? selectedOptionIndex;
  final List<int> disabledOptionIndexes = [];
  final Set<String> answeredQuestionIds = {};
  final Set<String> correctlyAnsweredQuestionIds = {};
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
    LivesService.refresh();
    playerHp = LivesService.lives.value;
    status = GameStatus.playing;
    AudioService.playBattleMusic(boss: isBossBattle);
    // Rugido del monstruo al aparecer (los jefes tienen su propia entrada).
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!_isDisposed) AudioService.playBattleStart(boss: isBossBattle);
    });
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
    answeredQuestionIds.add(question.id);

    if (isCorrect) {
      AudioService.playSuccess();
      if (correctlyAnsweredQuestionIds.add(question.id)) {
        QuestService.incrementProgress('answer_trivia_10');
        final hitsToDefeat = config.correctAnswersToDefeat;
        final damagePerAnswer = (enemyMaxHp / hitsToDefeat).ceil();
        final remainingHp =
            (enemyHp - damagePerAnswer).clamp(0, enemyMaxHp).toInt();
        final hasUnansweredQuestions = questions.any(
          (candidate) => !answeredQuestionIds.contains(candidate.id),
        );
        enemyHp = hasUnansweredQuestions && remainingHp == 0
            ? 1
            : remainingHp;
      }
    } else {
      AudioService.playWrong();
      mistakes++;
      LivesService.loseLife(); // se guarda al momento: salir no la devuelve
      playerHp = LivesService.lives.value;
      incorrectAnswersSinceMonsterAttack++;
      // Alarma cuando solo queda una vida.
      if (playerHp == 1) {
        Future.delayed(const Duration(milliseconds: 700), AudioService.playLowHealth);
      }
    }
    notifyListeners();
  }

  void continueAfterAnswer() {
    if (_isDisposed || !isAnswered || status != GameStatus.playing) return;

    if (playerHp <= 0) {
      _handleDefeat();
    } else if (enemyHp > 0 && incorrectAnswersSinceMonsterAttack >= 2) {
      _applyMonsterRewind();
    } else {
      final nextQuestionIndex = _nextUnansweredQuestionIndex();
      if (nextQuestionIndex >= 0) {
        _showQuestionAt(nextQuestionIndex);
      } else if (enemyHp <= 0) {
        _handleVictory();
      } else {
        _appendQuestionOrDefeat();
      }
    }
  }

  int _nextUnansweredQuestionIndex() {
    for (var index = currentQuestionIndex + 1;
        index < questions.length;
        index++) {
      if (!answeredQuestionIds.contains(questions[index].id)) return index;
    }
    for (var index = 0; index <= currentQuestionIndex; index++) {
      if (!answeredQuestionIds.contains(questions[index].id)) return index;
    }
    return -1;
  }

  void _showQuestionAt(int index) {
    if (_isDisposed) return;
    currentQuestionIndex = index;
    isAnswered = false;
    selectedOptionIndex = null;
    disabledOptionIndexes.clear();
    notifyListeners();
  }

  void _appendQuestionOrDefeat() {
    final additionalQuestion = QuestionBank.getAdditionalQuestion(
      world: worldId,
      chapter: chapterId,
      level: levelNumber,
      questionIndex: questions.length,
      difficulty: config.difficulty,
      isMiniChallenge: isMiniChallenge,
      usedQuestionIds: questions.map((question) => question.id).toSet(),
    );
    if (additionalQuestion == null) {
      _handleDefeat();
      return;
    }
    final additionalQuestionIndex = questions.length;
    questions.add(additionalQuestion);
    monsterReaction = '¡El monstruo resiste! Responde una pregunta adicional.';
    _showQuestionAt(additionalQuestionIndex);
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

  /// Suma XP y, si el jugador sube de nivel, suena la fanfarria de nivel
  /// después de las estrellas de la pantalla de victoria.
  void _addExperienceWithSound(int xp) {
    final levelBefore = profile!.level;
    profile!.addExperience(xp);
    if (profile!.level > levelBefore) {
      // Premio por subir de nivel: vidas llenas.
      LivesService.refillAll();
      Future.delayed(const Duration(milliseconds: 2600), AudioService.playLevelUp);
    }
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
        _addExperienceWithSound(xpReward);
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

    // Antes las estrellas dependían de las vidas que quedaban; ahora las
    // vidas vienen del nivel anterior, así que cuentan los fallos de ESTE.
    starsEarned = mistakes == 0
        ? 3
        : mistakes == 1
        ? 2
        : 1;

    // 1. Guardar Monedas y XP en el perfil local
    if (profile != null) {
      profile!.coins += coinsReward;
      _addExperienceWithSound(xpReward);
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
    AudioService.playDefeatSound();
    notifyListeners();
  }

  // =================================================================
  // REVIVIR TRAS PERDER TODAS LAS VIDAS
  // =================================================================

  /// Solo se puede revivir viendo un video UNA vez por batalla.
  /// Así el reto se mantiene y las pociones (que se venden en la tienda)
  /// siguen teniendo valor. Como el controlador se crea en cada batalla,
  /// el permiso se renueva solo al empezar la siguiente.
  bool hasUsedAdRevive = false;

  /// Revivir solo tiene sentido si la derrota fue por quedarse sin vidas.
  /// (Si el monstruo resistió porque se acabaron las preguntas, una vida
  /// más no cambiaría nada.)
  bool get canRevive =>
      !_isDisposed && status == GameStatus.defeat && playerHp <= 0;

  bool get canReviveWithAd => canRevive && !hasUsedAdRevive;

  /// Minijefes y jefes de mundo tienen su propia música, más intensa.
  bool get isBossBattle =>
      config.type == LevelType.miniBoss || config.type == LevelType.worldBoss;

  bool get canReviveWithPotion =>
      canRevive && (profile?.healthPotions ?? 0) > 0;

  /// Llamar SOLO cuando AdMob confirme que el jugador vio el video entero.
  void reviveWithAd() {
    if (!canReviveWithAd) return;
    hasUsedAdRevive = true;
    AudioService.playRevive();
    _revive();
  }

  /// Gasta una poción para volver con 1 vida. Devuelve false si no hay.
  Future<bool> reviveWithPotion() async {
    if (!canReviveWithPotion) return false;
    profile!.healthPotions--;
    AudioService.playRevive();
    _revive();
    await SaveService.savePlayerData(profile!);
    QuestService.incrementProgress('use_potion_2');
    return true;
  }

  void _revive() {
    LivesService.setLives(1);
    playerHp = 1;
    status = GameStatus.playing;
    AudioService.playBattleMusic(boss: isBossBattle);
    // La derrota ocurrió justo después de una respuesta incorrecta, así que
    // seguimos exactamente como si el jugador no hubiera caído: siguiente
    // pregunta, o el retroceso del monstruo si acumulaba 2 errores.
    continueAfterAnswer();
    if (!_isDisposed) notifyListeners();
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
    LivesService.addLives(1);
    playerHp = LivesService.lives.value;
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
