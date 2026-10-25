import 'package:flutter/foundation.dart';

import '../models/player_profile.dart';
import 'cloud_service.dart';
import 'save_service.dart';

/// Mejoras del luchador que se compran con monedas en la Tienda.
enum FighterUpgrade {
  health('health', '❤️', 'VIDA', 'Más vida en cada round de pelea.'),
  power('power', '👊', 'FUERZA', 'Tus golpes quitan más vida.'),
  superCharge('super', '⚡', 'SUPER', 'La barra de SUPER se llena antes.');

  const FighterUpgrade(this.id, this.emoji, this.title, this.description);

  /// Clave con la que se guarda en el perfil (no cambiarla nunca).
  final String id;
  final String emoji;
  final String title;
  final String description;
}

/// Reglas de las peleas tipo "Street Fighter" y de las mejoras.
///
/// En cada mundo hay tres peleas: el guardián del capítulo 1, el del
/// capítulo 2 y la batalla final (último nivel del mundo). Para entrar
/// hay que haber ganado suficientes estrellas en ESE mundo. Así el jugador
/// tiene que jugar bien los niveles normales (3 estrellas = sin fallar),
/// no solo pasarlos.
///
/// Todos los números del equilibrio del juego están aquí juntos, para
/// poder ajustarlos sin buscar por todo el código.
class FighterService {
  FighterService._();

  // =================================================================
  // MEJORAS
  // =================================================================

  static const int maxUpgradeLevel = 5;

  /// Precio de cada nivel de mejora (del 1 al 5). Sube rápido para que
  /// mejorar al máximo sea un objetivo a largo plazo.
  static const List<int> upgradeCosts = [150, 300, 500, 800, 1200];

  static int levelOf(PlayerProfile profile, FighterUpgrade upgrade) =>
      (profile.fighterUpgrades[upgrade.id] ?? 0).clamp(0, maxUpgradeLevel).toInt();

  /// Precio del SIGUIENTE nivel, o null si ya está al máximo.
  static int? nextCost(PlayerProfile profile, FighterUpgrade upgrade) {
    final level = levelOf(profile, upgrade);
    return level >= maxUpgradeLevel ? null : upgradeCosts[level];
  }

  /// Compra el siguiente nivel. Devuelve false si no alcanza el dinero
  /// o si ya estaba al máximo.
  static Future<bool> buy(PlayerProfile profile, FighterUpgrade upgrade) async {
    final cost = nextCost(profile, upgrade);
    if (cost == null || profile.coins < cost) return false;
    profile.coins -= cost;
    profile.fighterUpgrades[upgrade.id] = levelOf(profile, upgrade) + 1;
    await SaveService.savePlayerData(profile);
    try {
      await CloudService.syncProfileToCloud(profile);
    } catch (e) {
      debugPrint('No se pudo sincronizar la mejora: $e');
    }
    return true;
  }

  /// Vida del jugador en cada round: 100 + 15 por nivel de VIDA (máx. 175).
  static int playerMaxHp(PlayerProfile? profile) =>
      100 + 15 * (profile == null ? 0 : levelOf(profile, FighterUpgrade.health));

  /// Multiplicador de daño: +10 % por nivel de FUERZA (máx. ×1,5).
  static double powerMultiplier(PlayerProfile? profile) =>
      1 + 0.10 * (profile == null ? 0 : levelOf(profile, FighterUpgrade.power));

  /// Cuánto se llena la barra de SUPER con cada acierto (0..1).
  /// Sin mejoras: 3 aciertos. Con SUPER al máximo: 2 aciertos.
  static double superFillPerHit(PlayerProfile? profile) =>
      0.34 + 0.04 * (profile == null ? 0 : levelOf(profile, FighterUpgrade.superCharge));

  // =================================================================
  // PELEAS
  // =================================================================

  /// En el mapa, el nivel 5 de cada capítulo es una pelea.
  static bool isFightLevel(int level) => level == 5;

  /// Estrellas del mundo necesarias para entrar a la pelea de cada capítulo.
  ///  - Capítulo 1: 8 de las 12 posibles en los 4 niveles anteriores.
  ///  - Capítulo 2: 18 de 27 (incluye la primera pelea).
  ///  - Batalla final: 30 de 42.
  /// Es alrededor de 2/3: obliga a repetir algún nivel para sacar 3★.
  static int starsRequired(int chapter) => switch (chapter) {
        1 => 8,
        2 => 18,
        _ => 30,
      };
}

/// Números de una pelea concreta, según el mundo y si es la final.
class FightRules {
  FightRules({required this.world, required this.isFinal});

  final int world;
  final bool isFinal;

  /// Rounds que hay que ganar (al mejor de 3).
  int get roundsToWin => 2;

  /// Vida del monstruo en cada round.
  int get enemyHp => isFinal ? 150 + 25 * (world - 1) : 100 + 20 * (world - 1);

  /// Daño del monstruo cuando fallas o se acaba el tiempo.
  int get enemyDamage => isFinal ? 30 + 6 * (world - 1) : 25 + 5 * (world - 1);

  /// En la final, en el último round el monstruo se enfurece y pega más.
  double get enragedMultiplier => isFinal ? 1.3 : 1.0;

  /// Segundos para responder cada pregunta: menos en mundos avanzados
  /// y en la final.
  int get secondsPerQuestion =>
    (isFinal ? 20 - 2 * (world - 1) : 25 - 2 * (world - 1)).clamp(12, 25).toInt();

  /// Daño base de un acierto (antes de velocidad y FUERZA).
  int get baseDamage => 22;

  /// Daño base del ataque SUPER.
  int get superDamage => 45;

  /// Vida que devuelve una poción durante la pelea.
  int get potionHeal => 40;

  /// Monedas, XP y gemas al ganar por primera vez.
  /// Al repetir una pelea ya ganada se da la cuarta parte (sin gemas).
  int get coinsReward => isFinal ? 150 + 50 * world : 60 + 20 * world;
  int get xpReward => isFinal ? 120 + 30 * world : 50 + 10 * world;
  int get gemsReward => isFinal ? 3 : 0;
}
