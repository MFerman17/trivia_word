import 'package:flutter/foundation.dart';
import '../models/player_profile.dart';
import '../models/question.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import '../services/question_bank.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';

enum GameStatus { loading, playing, victory, defeat }

class GameController extends ChangeNotifier {
  final int worldId;
  final int chapterId;
  final int levelNumber;

  PlayerProfile? profile;
  List<Question> questions = [];
  int currentQuestionIndex = 0;
  int playerHp = 3;
  final int maxPlayerHp = 3;
  
  GameStatus status = GameStatus.loading;
  bool isAnswered = false;
  int? selectedOptionIndex;
  final List<int> disabledOptionIndexes = [];

  int starsEarned = 1;
  int coinsReward = 50;
  int xpReward = 40;

  GameController({
    required this.worldId,
    required this.chapterId,
    required this.levelNumber,
  });

  Question? get currentQuestion =>
      questions.isNotEmpty && currentQuestionIndex < questions.length
          ? questions[currentQuestionIndex]
          : null;

  Future<void> loadInitialData() async {
    status = GameStatus.loading;
    notifyListeners();

    profile = await SaveService.loadPlayerData();
    questions = QuestionBank.getQuestionsForLevel(worldId, chapterId, levelNumber);

    status = GameStatus.playing;
    notifyListeners();
  }

  void selectAnswer(int index, Function(String) onSnackBarMessage) {
    if (isAnswered || questions.isEmpty || disabledOptionIndexes.contains(index)) {
      return;
    }

    selectedOptionIndex = index;
    isAnswered = true;
    notifyListeners();

    final question = currentQuestion;
    if (question == null) return;

    final isCorrect = (index == question.correctIndex);

    if (isCorrect) {
      AudioService.playSuccess();
      QuestService.incrementProgress('answer_trivia_10');
    } else {
      AudioService.playDamage();
      playerHp--;
    }
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (playerHp <= 0) {
        _handleDefeat();
      } else if (currentQuestionIndex + 1 < questions.length) {
        _nextQuestion();
      } else {
        _handleVictory();
      }
    });
  }

  void _nextQuestion() {
    currentQuestionIndex++;
    isAnswered = false;
    selectedOptionIndex = null;
    disabledOptionIndexes.clear();
    notifyListeners();
  }

  void _handleVictory() async {
    status = GameStatus.victory;
    AudioService.playVictorySound();
    QuestService.incrementProgress('win_battles_3');

    starsEarned = playerHp == 3 ? 3 : (playerHp == 2 ? 2 : 1);

    if (profile != null) {
      profile!.coins += coinsReward;
      profile!.addExperience(xpReward);
      profile!.addStars(starsEarned);
      await SaveService.savePlayerData(profile!);
    }

    StageProgress currentProgress = StageProgress(
      worldId: worldId,
      chapterId: chapterId,
      levelNumber: levelNumber,
      stars: starsEarned,
      isUnlocked: true,
    );
    await SaveService.saveStageProgress(currentProgress);

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

    notifyListeners();
  }

  void _handleDefeat() {
    status = GameStatus.defeat;
    AudioService.playDamage();
    notifyListeners();
  }

  void usePotion(Function(String) showSnackBar) async {
    if (profile == null) return;

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
    notifyListeners();

    await SaveService.savePlayerData(profile!);
    QuestService.incrementProgress('use_potion_2');
    showSnackBar('¡Has recuperado 1 vida!');
  }

  void useHint(Function(String) showSnackBar) async {
    if (profile == null || isAnswered || questions.isEmpty) return;

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
    notifyListeners();

    await SaveService.savePlayerData(profile!);
    showSnackBar('¡Se ha descartado una opción incorrecta!');
  }
}