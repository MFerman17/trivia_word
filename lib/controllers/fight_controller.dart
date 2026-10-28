import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/chapter_story.dart';
import '../models/level_config.dart';
import '../models/player_profile.dart';
import '../models/question.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import '../services/chapter_story_service.dart';
import '../services/cloud_service.dart';
import '../services/fighter_service.dart';
import '../services/quest_service.dart';
import '../services/question_bank.dart';
import '../services/question_repository.dart';
import '../services/save_service.dart';
import '../services/lives_service.dart';
import '../l10n/l10n.dart';
import '../services/vibration_service.dart';
import '../services/cheer_service.dart';

/// Fases de la pelea, en el orden en que ocurren.
enum FightPhase {
  loading,
  roundIntro, // "ROUND 1 · ¡PELEA!"
  question, // corre el reloj, el jugador elige
  feedback, // se ve el golpe y la respuesta correcta
  roundEnd, // "K.O."
  victory,
  defeat,
}

/// Qué acaba de pasar, para que la pantalla anime a los luchadores.
enum FightAction { none, punch, kick, special, enemyHit, timeout }

/// Lógica de las peleas tipo "Street Fighter".
///
/// Reglas (los números están en FighterService/FightRules):
///  - Al mejor de 3 rounds. En cada round los dos empiezan con la vida llena.
///  - Cada pregunta tiene reloj. Acertar = golpear. Cuanto más rápido,
///    más fuerte: PATADA (rápido, ×1,5), PUÑETAZO (×1) o golpe flojo (×0,7).
///  - Fallar o quedarse sin tiempo = el monstruo te golpea.
///  - Cada acierto llena la barra de SUPER; llena, el jugador puede lanzar
///    un ataque especial.
///  - En la batalla final, en el último round el monstruo se enfurece.
class FightController extends ChangeNotifier {
  FightController({
    required this.worldId,
    required this.chapterId,
    required this.levelNumber,
  });

  final int worldId;
  final int chapterId;
  final int levelNumber;

  late final LevelConfig config =
      QuestionBank.getConfigForLevel(worldId, chapterId, levelNumber);
  late final FightRules rules =
      FightRules(world: worldId, isFinal: config.type == LevelType.worldBoss);

  bool get isFinal => rules.isFinal;

  PlayerProfile? profile;
  FightPhase phase = FightPhase.loading;

  // --- Rounds ---
  int round = 1;
  int playerRounds = 0;
  int enemyRounds = 0;

  /// En la final, el último round posible (1-1) es "furioso".
  bool get isEnraged => isFinal && playerRounds == 1 && enemyRounds == 1;

  // --- Vida y barras ---
  late int playerMaxHp = FighterService.playerMaxHp(profile);
  late int playerHp = playerMaxHp;
  int get enemyMaxHp => rules.enemyHp;
  late int enemyHp = enemyMaxHp;

  /// Barra de SUPER, de 0 a 1.
  double superMeter = 0;
  bool get superReady => superMeter >= 1;

  /// Aciertos seguidos (para el "COMBO").
  int combo = 0;
  int bestCombo = 0;

  // --- Pregunta actual ---
  final List<Question> _queue = [];
  final Set<String> _usedIds = {};
  Question? question;
  int? selectedIndex;
  final List<int> disabledOptions = [];

  /// Segundos que quedan para responder.
  double timeLeft = 0;
  int get secondsPerQuestion => rules.secondsPerQuestion;
  double get timeFraction => (timeLeft / secondsPerQuestion).clamp(0.0, 1.0);

  // --- Último golpe (lo usa la pantalla para animar) ---
  FightAction lastAction = FightAction.none;

  /// Sube en 1 con cada acción, así la pantalla sabe que hay una nueva
  /// aunque se repita el mismo tipo de golpe.
  int actionId = 0;
  int lastDamage = 0;
  String actionLabel = '';

  /// Frase de ánimo que acompaña al golpe (cambia en cada uno).
  String cheer = '';

  // --- Resultado ---
  int starsEarned = 0;
  int coinsEarned = 0;
  int xpEarned = 0;
  int gemsEarned = 0;
  bool firstWin = false;

  /// true cuando ya se calcularon y guardaron los premios de la victoria.
  bool resultReady = false;
  ChapterStory? chapterStory;

  Timer? _clock;
  bool _disposed = false;

  // =================================================================
  // INICIO
  // =================================================================

  Future<void> load() async {
    profile = await SaveService.loadPlayerData();
    playerMaxHp = FighterService.playerMaxHp(profile);
    playerHp = playerMaxHp;
    if (_disposed) return;
    AudioService.playBattleMusic(boss: true);
    _startRound();
  }

  void _startRound() {
    playerHp = playerMaxHp;
    enemyHp = enemyMaxHp;
    lastAction = FightAction.none;
    phase = FightPhase.roundIntro;
    notifyListeners();
    AudioService.playBattleStart(boss: isFinal || round > 1);
    _after(1800, _nextQuestion);
  }

  // =================================================================
  // PREGUNTAS
  // =================================================================

  /// Dificultad de las preguntas: la del nivel en el mapa (los guardianes
  /// y la final ya van un escalón por encima del resto del mundo).
  int get difficulty => config.difficulty;

  Question _takeQuestion() {
    if (_queue.isEmpty) {
      _queue.addAll(
        QuestionRepository.draw(difficulty: difficulty, count: 10, exclude: _usedIds),
      );
      if (_queue.isEmpty) {
        // Reserva: el generador de siempre si el banco no cargó.
        _queue.addAll(QuestionBank.getQuestionsForLevel(worldId, chapterId, levelNumber));
      }
    }
    final next = _queue.removeAt(0);
    _usedIds.add(next.id);
    return next;
  }

  void _nextQuestion() {
    if (_disposed) return;
    question = _takeQuestion();
    selectedIndex = null;
    disabledOptions.clear();
    timeLeft = secondsPerQuestion.toDouble();
    phase = FightPhase.question;
    notifyListeners();
    _startClock();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || phase != FightPhase.question) return;
      timeLeft = math.max(0, timeLeft - 0.1);
      if (timeLeft <= 0) {
        _clock?.cancel();
        _enemyStrikes(FightAction.timeout);
      } else {
        notifyListeners();
      }
    });
  }

  // =================================================================
  // ACCIONES DEL JUGADOR
  // =================================================================

  void answer(int index) {
    final q = question;
    if (phase != FightPhase.question || q == null || disabledOptions.contains(index)) {
      return;
    }
    _clock?.cancel();
    selectedIndex = index;

    if (index == q.correctIndex) {
      _playerStrikes();
    } else {
      _enemyStrikes(FightAction.enemyHit);
    }
  }

  void _playerStrikes() {
    // Velocidad: con más de 2/3 del tiempo, patada; con menos de 1/3, flojo.
    final speed = timeFraction;
    final FightAction action;
    final double multiplier;
    if (speed > 0.66) {
      action = FightAction.kick;
      multiplier = 1.5;
      actionLabel = L10n.current.fightKick;
    } else if (speed > 0.33) {
      action = FightAction.punch;
      multiplier = 1.0;
      actionLabel = L10n.current.fightPunch;
    } else {
      action = FightAction.punch;
      multiplier = 0.7;
      actionLabel = L10n.current.fightWeakHit;
    }

    combo++;
    bestCombo = math.max(bestCombo, combo);
    if (combo >= 3) actionLabel = L10n.current.fightCombo(combo);
    superMeter = math.min(1, superMeter + FighterService.superFillPerHit(profile));

    final damage =
        (rules.baseDamage * multiplier * FighterService.powerMultiplier(profile)).round();
    _hitEnemy(damage, action);
    AudioService.playSuccess();
    QuestService.track(QuestEvent.correctAnswer);
  }

  /// Ataque especial: se lanza cuando la barra está llena, sin pregunta.
  void useSuper() {
    if (phase != FightPhase.question || !superReady) return;
    _clock?.cancel();
    superMeter = 0;
    actionLabel = L10n.current.fightSuper;
    final damage = (rules.superDamage * FighterService.powerMultiplier(profile)).round();
    AudioService.playLevelUp();
    // La pregunta actual se cambia por otra al terminar la animación.
    _hitEnemy(damage, FightAction.special);
  }

  void _hitEnemy(int damage, FightAction action) {
    cheer = CheerService.next(correct: true);
    lastDamage = damage;
    lastAction = action;
    actionId++;
    enemyHp = math.max(0, enemyHp - damage);
    phase = FightPhase.feedback;
    notifyListeners();
    // Vibra justo cuando el golpe llega al monstruo (a mitad de la embestida).
    _after(220, () => VibrationService.hit(strong: action == FightAction.special));
    _after(action == FightAction.special ? 1500 : 1300, _afterExchange);
  }

  void _enemyStrikes(FightAction action) {
    cheer = CheerService.next(correct: false);
    combo = 0;
    final damage = (rules.enemyDamage * (isEnraged ? rules.enragedMultiplier : 1)).round();
    lastDamage = damage;
    lastAction = action;
    actionLabel = action == FightAction.timeout
        ? L10n.current.fightTimeUp
        : L10n.current.fightGotHit;
    actionId++;
    playerHp = math.max(0, playerHp - damage);
    phase = FightPhase.feedback;
    notifyListeners();
    AudioService.playWrong();
    _after(220, () => VibrationService.hit(strong: true));
    if (playerHp > 0 && playerHp <= playerMaxHp * 0.25) {
      _after(700, AudioService.playLowHealth);
    }
    // Más tiempo para leer la respuesta correcta.
    _after(2200, _afterExchange);
  }

  void _afterExchange() {
    if (_disposed) return;
    if (enemyHp <= 0) {
      _endRound(playerWon: true);
    } else if (playerHp <= 0) {
      _endRound(playerWon: false);
    } else {
      _nextQuestion();
    }
  }

  /// Poción: devuelve vida en mitad de la pelea (no gasta la pregunta).
  Future<void> usePotion() async {
    final p = profile;
    if (phase != FightPhase.question || p == null || p.healthPotions <= 0) return;
    if (playerHp >= playerMaxHp) return;
    p.healthPotions--;
    playerHp = math.min(playerMaxHp, playerHp + rules.potionHeal);
    AudioService.playPotionUse();
    notifyListeners();
    await SaveService.savePlayerData(p);
  }

  /// Pista: descarta una respuesta incorrecta.
  Future<void> useHint() async {
    final p = profile;
    final q = question;
    if (phase != FightPhase.question || p == null || q == null || p.letterHints <= 0) {
      return;
    }
    final wrong = [
      for (var i = 0; i < q.options.length; i++)
        if (i != q.correctIndex && !disabledOptions.contains(i)) i,
    ];
    if (wrong.length <= 1) return; // Siempre quedan al menos dos opciones.
    wrong.shuffle();
    disabledOptions.add(wrong.first);
    p.letterHints--;
    AudioService.playHintUse();
    notifyListeners();
    await SaveService.savePlayerData(p);
  }

  // =================================================================
  // FIN DE ROUND Y DE PELEA
  // =================================================================

  void _endRound({required bool playerWon}) {
    if (playerWon) {
      playerRounds++;
    } else {
      enemyRounds++;
    }
    phase = FightPhase.roundEnd;
    notifyListeners();
    // Antes sonaba siempre el rugido del monstruo, también cuando ganabas.
    // Ahora: al ganar el round, sonido de triunfo; al perderlo, el rugido.
    playerWon ? AudioService.playRoundWin() : AudioService.playSfx('monster_roar.mp3');

    _after(2400, () {
      if (playerRounds >= rules.roundsToWin) {
        _handleVictory();
      } else if (enemyRounds >= rules.roundsToWin) {
        _handleDefeat();
      } else {
        round++;
        _startRound();
      }
    });
  }

  Future<void> _handleVictory() async {
    phase = FightPhase.victory;
    // 3★ = sin perder un round y con media vida; 2★ = sin perder un round;
    // 1★ = ganando 2-1.
    starsEarned = enemyRounds > 0
        ? 1
        : playerHp >= playerMaxHp / 2
            ? 3
            : 2;
    notifyListeners();
    AudioService.playVictorySound();

    final previous = await SaveService.getStageProgress(worldId, chapterId, levelNumber);
    firstWin = previous.stars == 0;
    // Repetir una pelea ya ganada da la cuarta parte y sin gemas, para que
    // compense más avanzar que repetir siempre la misma.
    coinsEarned = firstWin ? rules.coinsReward : (rules.coinsReward / 4).round();
    xpEarned = firstWin ? rules.xpReward : (rules.xpReward / 4).round();
    gemsEarned = firstWin ? rules.gemsReward : 0;
    if (firstWin) chapterStory = ChapterStoryService.afterChapter(worldId, chapterId);

    final p = profile;
    if (p != null) {
      final levelBefore = p.level;
      p.coins += coinsEarned;
      p.gems += gemsEarned;
      p.addExperience(xpEarned);
      if (p.level > levelBefore) {
        LivesService.refillAll(); // premio por subir de nivel
        Future.delayed(const Duration(milliseconds: 2600), AudioService.playLevelUp);
      }
      await SaveService.savePlayerData(p);
    }
    QuestService.track(QuestEvent.levelWon);
    QuestService.track(QuestEvent.fightWon);
    if (starsEarned == 3) QuestService.track(QuestEvent.perfectLevel);
    QuestService.track(QuestEvent.starsEarned, amount: starsEarned - previous.stars);

    await SaveService.saveStageProgress(StageProgress(
      worldId: worldId,
      chapterId: chapterId,
      levelNumber: levelNumber,
      stars: starsEarned,
      isUnlocked: true,
    ));

    // Desbloquea el siguiente: primer nivel del capítulo o del mundo siguiente.
    var nextWorld = worldId;
    var nextChapter = chapterId + 1;
    if (nextChapter > 3) {
      nextChapter = 1;
      nextWorld++;
    }
    await SaveService.saveStageProgress(StageProgress(
      worldId: nextWorld,
      chapterId: nextChapter,
      levelNumber: 1,
      isUnlocked: true,
    ));

    if (p != null) {
      try {
        await CloudService.syncProfileToCloud(p);
      } catch (e) {
        debugPrint('No se pudo sincronizar la victoria de la pelea: $e');
      }
    }
    resultReady = true;
    if (!_disposed) notifyListeners();
  }

  void _handleDefeat() {
    // Perder una pelea cuesta una vida global (la vida de cada round es
    // otra cosa: se rellena en cada round).
    LivesService.loseLife();
    phase = FightPhase.defeat;
    notifyListeners();
    AudioService.playDefeatSound();
  }

  // =================================================================
  // UTILIDADES
  // =================================================================

  /// Ejecuta [action] tras [ms] milisegundos, salvo que ya se haya salido
  /// de la pantalla.
  void _after(int ms, VoidCallback action) {
    Future.delayed(Duration(milliseconds: ms), () {
      if (!_disposed) action();
    });
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    super.dispose();
  }
}
