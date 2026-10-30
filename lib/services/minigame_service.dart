import 'package:shared_preferences/shared_preferences.dart';

import '../config/world_map_config.dart';
import '../models/player_profile.dart';
import 'cloud_service.dart';
import 'save_service.dart';

/// Minijuegos disponibles. Cada portal del mapa ofrece uno.
enum MinigameType { memory, hangman }

/// Premio de un minijuego.
class MinigameReward {
  const MinigameReward({required this.coins, this.gems = 0, this.hints = 0});
  final int coins;
  final int gems;
  final int hints;
}

/// Portales de minijuegos del mapa.
///
/// - Hay un portal junto a los niveles 5 y 10 de cada capítulo (justo donde
///   termina cada tramo de sendero).
/// - Se abre al ganar ese nivel.
/// - Cada portal se puede jugar UNA vez al día: así el premio es un extra
///   que invita a volver, no una forma infinita de sacar monedas.
/// - Qué día se jugó se guarda solo en el teléfono.
class MinigameService {
  MinigameService._();

  /// Nivel del capítulo junto al que aparece cada portal (5 y 10).
  static List<int> get portalLevels => [
        for (int p = 1; p <= kSegmentsPerChapter; p++) p * kNodesPerSegment,
      ];

  static String _key(int world, int chapter, int level) =>
      'portal_w${world}_c${chapter}_l$level';

  static String _today() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// true si el portal ya se jugó hoy.
  static Future<bool> playedToday(int world, int chapter, int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key(world, chapter, level)) == _today();
    } catch (_) {
      return false;
    }
  }

  /// Portales jugados hoy (para pintarlos apagados en el mapa).
  static Future<Set<String>> playedTodayKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _today();
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith('portal_') && prefs.getString(key) == today) key,
      };
    } catch (_) {
      return {};
    }
  }

  static String portalKey(int world, int chapter, int level) => _key(world, chapter, level);

  /// Cada portal tiene su juego fijo, alternando por el mapa.
  static MinigameType typeFor(int world, int chapter, int level) {
    final index = (world * 7 + chapter * 3 + level ~/ kNodesPerSegment) % MinigameType.values.length;
    return MinigameType.values[index];
  }

  /// El premio crece con el mundo. Ganar da el premio completo; perder,
  /// un consuelo pequeño (así nunca se siente tiempo perdido).
  static MinigameReward rewardFor(int world, {required bool won}) {
    if (!won) return const MinigameReward(coins: 10);
    return MinigameReward(
      coins: 30 + world * 15,
      gems: world >= 3 ? 1 : 0,
      hints: world.isOdd ? 1 : 0,
    );
  }

  /// Marca el portal como jugado hoy y entrega el premio.
  static Future<MinigameReward> finish({
    required int world,
    required int chapter,
    required int level,
    required bool won,
  }) async {
    final reward = rewardFor(world, won: won);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(world, chapter, level), _today());
    } catch (_) {}
    final PlayerProfile profile = await SaveService.loadPlayerData();
    profile.coins += reward.coins;
    profile.gems += reward.gems;
    profile.letterHints += reward.hints;
    await SaveService.savePlayerData(profile);
    try {
      await CloudService.syncProfileToCloud(profile);
    } catch (_) {}
    return reward;
  }
}
