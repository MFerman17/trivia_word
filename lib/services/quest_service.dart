import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest_model.dart';
import '../models/player_profile.dart';
import '../services/save_service.dart';

class QuestService {
  static const String _questsKey = 'user_quests_data';

  // Plantillas de misiones predeterminadas
  static List<QuestModel> getDefaultQuests() {
    return [
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
    ];
  }

  // Carga misiones guardadas o las inicializa
  static Future<List<QuestModel>> loadQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString(_questsKey);
    final defaults = getDefaultQuests();

    if (rawData == null) return defaults;

    try {
      final List<dynamic> decoded = jsonDecode(rawData);
      Map<String, dynamic> savedMap = {
        for (var item in decoded) item['id']: item
      };

      return defaults.map((template) {
        if (savedMap.containsKey(template.id)) {
          return QuestModel.fromJson(savedMap[template.id], template);
        }
        return template;
      }).toList();
    } catch (_) {
      return defaults;
    }
  }

  // Incrementa el progreso de una misión específica
  static Future<void> incrementProgress(String questId, {int amount = 1}) async {
    List<QuestModel> quests = await loadQuests();
    bool updated = false;

    for (var quest in quests) {
      if (quest.id == questId && !quest.isClaimed) {
        quest.currentAmount += amount;
        if (quest.currentAmount > quest.targetAmount) {
          quest.currentAmount = quest.targetAmount;
        }
        updated = true;
        break;
      }
    }

    if (updated) {
      await _saveQuests(quests);
    }
  }

  // Reclama la recompensa de una misión completada
  static Future<bool> claimReward(String questId, PlayerProfile profile) async {
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
  }
}