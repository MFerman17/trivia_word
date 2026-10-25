import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile.dart';
import '../models/stage_progress.dart';

class SaveService {
  // Clave única para todo el proyecto
  static const String _keyProfile = 'player_profile_json';
  static Future<void> Function()? onLocalSaveChanged;

  static Future<void> notifyLocalSaveChanged() async {
    try {
      await onLocalSaveChanged?.call();
    } catch (e) {
      debugPrint('No se pudo sincronizar el guardado en la nube: $e');
    }
  }

  /// Exporta el progreso local en un formato versionado para sincronizarlo.
  static Future<Map<String, dynamic>> exportCloudSave() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_keyProfile);
    Map<String, dynamic> profile = PlayerProfile().toMap();
    if (profileJson != null) {
      try {
        profile = Map<String, dynamic>.from(jsonDecode(profileJson));
      } catch (e) {
        debugPrint('No se pudo exportar el perfil local: $e');
      }
    }

    final stages = <String, dynamic>{};
    for (final key in prefs.getKeys().where((key) => key.startsWith('stage_'))) {
      final value = prefs.getString(key);
      if (value == null) continue;
      try {
        stages[key.substring('stage_'.length)] = jsonDecode(value);
      } catch (e) {
        debugPrint('No se pudo exportar el progreso $key: $e');
      }
    }

    List<dynamic> quests = [];
    final questsJson = prefs.getString('user_quests_data');
    if (questsJson != null) {
      try {
        quests = List<dynamic>.from(jsonDecode(questsJson));
      } catch (e) {
        debugPrint('No se pudieron exportar las misiones: $e');
      }
    }

    final miniRewards = <String, String>{};
    for (final key in prefs.getKeys().where((key) => key.startsWith('mini_reward_'))) {
      final value = prefs.getString(key);
      if (value != null) miniRewards[key] = value;
    }

    return {
      'schemaVersion': 1,
      'profile': profile,
      'stages': stages,
      'quests': quests,
      'miniRewards': miniRewards,
    };
  }

  /// Restaura una copia descargada. Se escribe directamente para evitar bucles
  /// de sincronización durante la propia restauración.
  static Future<void> importCloudSave(Map<String, dynamic> save) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = Map<String, dynamic>.from(save['profile'] as Map);
    await prefs.setString(_keyProfile, jsonEncode(profile));

    for (final key in prefs.getKeys().where((key) => key.startsWith('stage_')).toList()) {
      await prefs.remove(key);
    }
    final stages = Map<String, dynamic>.from(save['stages'] as Map? ?? {});
    for (final entry in stages.entries) {
      await prefs.setString('stage_${entry.key}', jsonEncode(entry.value));
    }

    await prefs.setString(
      'user_quests_data',
      jsonEncode(List<dynamic>.from(save['quests'] as List? ?? [])),
    );

    for (final key in prefs.getKeys().where((key) => key.startsWith('mini_reward_')).toList()) {
      await prefs.remove(key);
    }
    final miniRewards = Map<String, dynamic>.from(save['miniRewards'] as Map? ?? {});
    for (final entry in miniRewards.entries) {
      if (entry.value is String) await prefs.setString(entry.key, entry.value as String);
    }
  }

  static bool hasMeaningfulProgress(Map<String, dynamic> save) {
    final profile = Map<String, dynamic>.from(save['profile'] as Map? ?? {});
    final hasProfileProgress = (profile['level'] as num? ?? 1) > 1 ||
        (profile['experience'] as num? ?? 0) > 0 ||
        (profile['coins'] as num? ?? 100) != 100 ||
        (profile['gems'] as num? ?? 10) != 10 ||
        (profile['healthPotions'] as num? ?? 1) != 1 ||
        (profile['letterHints'] as num? ?? 2) != 2 ||
        (profile['name'] ?? 'Jugador 1') != 'Jugador 1' ||
        (profile['avatarCharacterId'] ?? 'explorador') != 'explorador' ||
        (profile['avatarFrameId'] ?? 'basico') != 'basico' ||
        (profile['avatarAccessoryId'] ?? 'ninguno') != 'ninguno' ||
        (profile['ownedAvatarCharacters'] as List? ?? const []).length > 1 ||
        (profile['ownedAvatarFrames'] as List? ?? const []).length > 1 ||
        (profile['ownedAvatarAccessories'] as List? ?? const []).length > 1;
    final stages = Map<String, dynamic>.from(save['stages'] as Map? ?? {});
    final hasStageProgress = stages.values.any((value) {
      final stage = Map<String, dynamic>.from(value as Map);
      return (stage['stars'] as num? ?? 0) > 0 || (stage['highScore'] as num? ?? 0) > 0;
    });
    final quests = List<dynamic>.from(save['quests'] as List? ?? []);
    final hasQuestProgress = quests.any((value) {
      final quest = Map<String, dynamic>.from(value as Map);
      return (quest['currentAmount'] as num? ?? 0) > 0 || quest['isClaimed'] == true;
    });
    return hasProfileProgress || hasStageProgress || hasQuestProgress ||
        (save['miniRewards'] as Map? ?? {}).isNotEmpty;
  }

  /// Limita la recompensa de cada mini-reto a una vez por día en este
  /// dispositivo. Las recompensas laterales no alteran estrellas ni ranking.
  static Future<bool> claimMiniChallengeReward(String challengeId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final key = 'mini_reward_$challengeId';
    if (prefs.getString(key) == date) return false;
    await prefs.setString(key, date);
    await notifyLocalSaveChanged();
    return true;
  }

  /// Borra del teléfono todo el avance (perfil, niveles, misiones, vidas,
  /// historial de preguntas...). Se conservan el idioma y el sonido, que son
  /// preferencias del dispositivo y no datos del jugador.
  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    const keep = {
      'app_language',
      'audio_music_on',
      'audio_sfx_on',
      'audio_music_volume',
      'audio_sfx_volume',
    };
    for (final key in prefs.getKeys().toList()) {
      if (!keep.contains(key)) await prefs.remove(key);
    }
  }

  // =========================================================================
  // DATOS DEL JUGADOR
  // =========================================================================

  /// Guardar datos del perfil del jugador
  static Future<void> savePlayerData(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, profile.toJson());
    await notifyLocalSaveChanged();
  }

  /// Cargar datos del perfil del jugador (Sincroniza automáticamente las estrellas)
  static Future<PlayerProfile> loadPlayerData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_keyProfile);

    PlayerProfile profile = PlayerProfile();

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        profile = PlayerProfile.fromJson(jsonString);
      } catch (e) {
        debugPrint('Error parseando PlayerProfile: $e');
      }
    }

    // Sincronizar automáticamente las estrellas reales acumuladas en los niveles
    profile.totalStars = await getTotalStarsObtained();
    return profile;
  }

  /// Añadir recompensas de XP, monedas y recalcular estrellas
  static Future<PlayerProfile> addRewards({
    required int coinsEarned,
    required int xpEarned,
    int starsEarned = 0,
  }) async {
    PlayerProfile profile = await loadPlayerData();

    // Sumar monedas
    profile.coins += coinsEarned;

    // Procesar experiencia usando el método propio de PlayerProfile
    profile.addExperience(xpEarned);

    // Recalcular estrellas globales acumuladas
    profile.totalStars = await getTotalStarsObtained();

    // Guardar cambios
    await savePlayerData(profile);
    return profile;
  }

  // =========================================================================
  // PROGRESO DE FASES Y ESTRELLAS
  // =========================================================================

  static Future<void> saveStageProgress(StageProgress progress) async {
    final prefs = await SharedPreferences.getInstance();

    final existingProgress = await getStageProgress(
      progress.worldId,
      progress.chapterId,
      progress.levelNumber,
    );

    int bestStars = progress.stars > existingProgress.stars ? progress.stars : existingProgress.stars;
    int bestScore = progress.highScore > existingProgress.highScore ? progress.highScore : existingProgress.highScore;

    final updatedProgress = StageProgress(
      worldId: progress.worldId,
      chapterId: progress.chapterId,
      levelNumber: progress.levelNumber,
      stars: bestStars,
      highScore: bestScore,
      isUnlocked: progress.isUnlocked,
    );

    String key = 'stage_${updatedProgress.stageKey}';
    String jsonString = jsonEncode(updatedProgress.toJson());
    await prefs.setString(key, jsonString);

    // Actualizar las estrellas en el perfil global
    PlayerProfile profile = await loadPlayerData();
    profile.totalStars = await getTotalStarsObtained();
    await savePlayerData(profile);
  }

  static Future<StageProgress> getStageProgress(int worldId, int chapterId, int levelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'stage_w${worldId}_c${chapterId}_l$levelNumber';
    String? jsonString = prefs.getString(key);

    if (jsonString != null) {
      try {
        return StageProgress.fromJson(jsonDecode(jsonString));
      } catch (e) {
        debugPrint('Error leyendo la clave $key: $e');
      }
    }

    bool defaultUnlocked = (worldId == 1 && chapterId == 1 && levelNumber == 1);
    return StageProgress(
      worldId: worldId,
      chapterId: chapterId,
      levelNumber: levelNumber,
      stars: 0,
      highScore: 0,
      isUnlocked: defaultUnlocked,
    );
  }

  static Future<int> getTotalStarsObtained() async {
    final prefs = await SharedPreferences.getInstance();
    int totalStars = 0;
    Set<String> keys = prefs.getKeys();

    for (String key in keys) {
      if (key.startsWith('stage_')) {
        String? jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            var data = jsonDecode(jsonString);
            totalStars += (data['stars'] as int? ?? 0);
          } catch (e) {
            debugPrint('Error leyendo estrellas en $key: $e');
          }
        }
      }
    }
    return totalStars;
  }
}
