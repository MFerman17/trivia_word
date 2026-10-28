import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest_model.dart';
import '../models/player_profile.dart';
import '../services/save_service.dart';

/// Cosas que pasan en el juego y que hacen avanzar misiones.
/// El juego solo avisa del suceso; aquí se decide qué misiones suben.
enum QuestEvent {
  correctAnswer,
  levelWon,
  fightWon,
  perfectLevel, // nivel ganado con 3 estrellas
  starsEarned, // estrellas NUEVAS conseguidas (amount = cuántas)
  potionUsed,
  hintUsed,
  shopPurchase,
  upgradeBought,
  miniChallengeWon,
}

class QuestService {
  static const String _questsKey = 'user_quests_data';

  /// Qué misiones avanza cada suceso.
  static const Map<QuestEvent, List<String>> _eventQuests = {
    QuestEvent.correctAnswer: ['daily_answer_15', 'answer_trivia_10', 'answer_trivia_100'],
    QuestEvent.levelWon: ['daily_win_3', 'win_battles_3', 'win_battles_25'],
    QuestEvent.fightWon: ['win_fights_3'],
    QuestEvent.perfectLevel: ['daily_perfect_1', 'perfect_10'],
    QuestEvent.starsEarned: ['stars_50'],
    QuestEvent.potionUsed: ['use_potion_2'],
    QuestEvent.hintUsed: ['daily_hint_2', 'use_hint_5'],
    QuestEvent.shopPurchase: ['buy_shop_item_1'],
    QuestEvent.upgradeBought: ['buy_upgrade_1'],
    QuestEvent.miniChallengeWon: ['mini_challenge_3'],
  };

  // Plantillas de misiones. Primero las diarias (se renuevan cada día),
  // luego los logros (se completan una sola vez).
  static List<QuestModel> getDefaultQuests() {
    return [
      // ---- DIARIAS ----
      QuestModel(
        id: 'daily_answer_15',
        title: 'Calentamiento',
        description: 'Acierta 15 preguntas hoy',
        targetAmount: 15,
        rewardCoins: 80,
        emoji: '☀️',
        daily: true,
      ),
      QuestModel(
        id: 'daily_win_3',
        title: 'Racha del día',
        description: 'Gana 3 niveles hoy',
        targetAmount: 3,
        rewardCoins: 100,
        emoji: '🏁',
        daily: true,
      ),
      QuestModel(
        id: 'daily_perfect_1',
        title: 'Sin fallos',
        description: 'Gana un nivel con 3 estrellas hoy',
        targetAmount: 1,
        rewardCoins: 60,
        rewardGems: 1,
        emoji: '🌟',
        daily: true,
      ),
      QuestModel(
        id: 'daily_hint_2',
        title: 'Pequeña ayuda',
        description: 'Usa 2 pistas hoy',
        targetAmount: 2,
        rewardCoins: 50,
        emoji: '💡',
        daily: true,
      ),
      // ---- LOGROS ----
      QuestModel(
        id: 'win_battles_3',
        title: 'Guerrero Novato',
        description: 'Gana 3 batallas en el mapa',
        targetAmount: 3,
        rewardCoins: 150,
        rewardGems: 2,
        emoji: '⚔️',
      ),
      QuestModel(
        id: 'answer_trivia_10',
        title: 'Mente Brillante',
        description: 'Responde correctamente 10 preguntas de trivia',
        targetAmount: 10,
        rewardCoins: 200,
        rewardGems: 1,
        emoji: '🧠',
      ),
      QuestModel(
        id: 'use_potion_2',
        title: 'Primeros Auxilios',
        description: 'Utiliza 2 pociones de vida durante un combate',
        targetAmount: 2,
        rewardCoins: 100,
        rewardGems: 1,
        emoji: '🧪',
      ),
      QuestModel(
        id: 'buy_shop_item_1',
        title: 'Cliente Frecuente',
        description: 'Realiza 1 compra de poción o mejora en la tienda',
        targetAmount: 1,
        rewardCoins: 80,
        rewardGems: 2,
        emoji: '🛍️',
      ),
      QuestModel(
        id: 'win_fights_3',
        title: 'Cazamonstruos',
        description: 'Vence a 3 monstruos de capítulo',
        targetAmount: 3,
        rewardCoins: 300,
        rewardGems: 3,
        emoji: '🐉',
      ),
      QuestModel(
        id: 'perfect_10',
        title: 'Perfeccionista',
        description: 'Gana 10 niveles con 3 estrellas',
        targetAmount: 10,
        rewardCoins: 250,
        rewardGems: 3,
        emoji: '💫',
      ),
      QuestModel(
        id: 'stars_50',
        title: 'Coleccionista de estrellas',
        description: 'Consigue 50 estrellas en el mapa',
        targetAmount: 50,
        rewardCoins: 400,
        rewardGems: 4,
        emoji: '⭐',
      ),
      QuestModel(
        id: 'answer_trivia_100',
        title: 'Enciclopedia',
        description: 'Acierta 100 preguntas',
        targetAmount: 100,
        rewardCoins: 500,
        rewardGems: 5,
        emoji: '📚',
      ),
      QuestModel(
        id: 'win_battles_25',
        title: 'Veterano',
        description: 'Gana 25 niveles',
        targetAmount: 25,
        rewardCoins: 350,
        rewardGems: 3,
        emoji: '🛡️',
      ),
      QuestModel(
        id: 'mini_challenge_3',
        title: 'Retador',
        description: 'Supera 3 mini-retos',
        targetAmount: 3,
        rewardCoins: 200,
        rewardGems: 2,
        emoji: '🎯',
      ),
      QuestModel(
        id: 'use_hint_5',
        title: 'Estratega',
        description: 'Usa 5 pistas',
        targetAmount: 5,
        rewardCoins: 120,
        rewardGems: 1,
        emoji: '🔍',
      ),
      QuestModel(
        id: 'buy_upgrade_1',
        title: 'Entrenamiento',
        description: 'Compra una mejora de luchador',
        targetAmount: 1,
        rewardCoins: 150,
        rewardGems: 2,
        emoji: '💪',
      ),
    ];
  }

  /// Fecha de hoy como texto (aaaa-mm-dd), en la hora del teléfono.
  static String _today() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  // Carga misiones guardadas o las inicializa
  static Future<List<QuestModel>> loadQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString(_questsKey);
    final today = _today();
    final defaults = getDefaultQuests();
    for (final q in defaults) {
      if (q.daily) q.day = today;
    }

    if (rawData == null) return defaults;

    try {
      final List<dynamic> decoded = jsonDecode(rawData);
      Map<String, dynamic> savedMap = {
        for (var item in decoded) item['id']: item
      };

      return defaults.map((template) {
        final saved = savedMap[template.id];
        if (saved == null) return template;
        final quest = QuestModel.fromJson(Map<String, dynamic>.from(saved), template);
        // Una diaria de otro día empieza de cero.
        if (quest.daily && quest.day != today) return template;
        return quest;
      }).toList();
    } catch (_) {
      return defaults;
    }
  }

  /// Las actualizaciones van en fila: si dos sucesos llegan a la vez,
  /// el segundo espera al primero (así ninguno borra el progreso del otro).
  static Future<void> _queue = Future.value();

  static Future<void> _enqueue(Future<void> Function() job) {
    final next = _queue.then((_) => job()).catchError((_) {});
    _queue = next;
    return next;
  }

  /// Avisa de un suceso del juego; sube todas las misiones que dependen de él.
  static Future<void> track(QuestEvent event, {int amount = 1}) {
    final ids = _eventQuests[event] ?? const [];
    if (ids.isEmpty || amount <= 0) return Future.value();
    return _enqueue(() => _increment(ids, amount));
  }

  // Incrementa el progreso de una misión específica
  static Future<void> incrementProgress(String questId, {int amount = 1}) {
    return _enqueue(() => _increment([questId], amount));
  }

  static Future<void> _increment(List<String> ids, int amount) async {
    final quests = await loadQuests();
    bool updated = false;

    for (final quest in quests) {
      if (ids.contains(quest.id) && !quest.isClaimed && !quest.isCompleted) {
        quest.currentAmount =
            (quest.currentAmount + amount).clamp(0, quest.targetAmount).toInt();
        updated = true;
      }
    }

    if (updated) {
      await _saveQuests(quests);
    }
  }

  // Reclama la recompensa de una misión completada
  static Future<bool> claimReward(String questId, PlayerProfile profile) async {
    bool ok = false;
    await _enqueue(() async => ok = await _claim(questId, profile));
    return ok;
  }

  static Future<bool> _claim(String questId, PlayerProfile profile) async {
    List<QuestModel> quests = await loadQuests();
    int index = quests.indexWhere((q) => q.id == questId);

    if (index != -1 && quests[index].isCompleted && !quests[index].isClaimed) {
      quests[index].isClaimed = true;
      profile.coins += quests[index].rewardCoins;
      profile.gems += quests[index].rewardGems;

      await _saveQuests(quests);
      await SaveService.savePlayerData(profile);
      return true;
    }
    return false;
  }

  static Future<void> _saveQuests(List<QuestModel> quests) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(quests.map((q) => q.toJson()).toList());
    await prefs.setString(_questsKey, encoded);
    await SaveService.notifyLocalSaveChanged();
  }
}
