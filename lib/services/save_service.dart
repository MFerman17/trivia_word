import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile.dart';
import '../models/stage_progress.dart';

class SaveService {
  // Clave única para todo el proyecto
  static const String _keyProfile = 'player_profile_json';

  // =========================================================================
  // DATOS DEL JUGADOR
  // =========================================================================

  /// Guardar datos del perfil del jugador
  static Future<void> savePlayerData(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, profile.toJson());
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