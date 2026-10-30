import '../models/player_profile.dart';

/// Poder que da un compañero mientras está equipado.
enum CompanionPower {
  none,
  coins, // más monedas al ganar niveles y peleas
  xp, // más experiencia
  freeHint, // una pista gratis en cada nivel
  fireDamage, // más daño en las peleas
  shield, // el primer fallo de cada nivel no quita vida
  phoenix, // en una pelea, te levanta una vez al caer
}

class Companion {
  const Companion({
    required this.id,
    required this.emoji,
    required this.power,
    this.coins = 0,
    this.gems = 0,
  });

  final String id;
  final String emoji;
  final CompanionPower power;
  final int coins;
  final int gems;
}

/// Compañeros: se compran en la tienda (pestaña Avatar) y se equipa UNO.
///
/// Antes eran solo adornos del avatar (la brújula y el dragoncito no hacían
/// nada). Ahora cada uno tiene un poder que se nota al jugar. Se guardan en
/// los mismos campos del perfil que los adornos (avatarAccessoryId y
/// ownedAvatarAccessories), así no hace falta cambiar la nube.
///
/// Por qué solo uno a la vez: si todos sumaran a la vez, el juego se
/// volvería demasiado fácil al comprarlos todos. Elegir uno es una decisión
/// ("¿quiero más monedas o pelear mejor?").
class CompanionService {
  CompanionService._();

  static const List<Companion> all = [
    Companion(id: 'ninguno', emoji: '—', power: CompanionPower.none),
    Companion(id: 'brujula', emoji: '🧭', power: CompanionPower.coins, coins: 100),
    Companion(id: 'libro', emoji: '📖', power: CompanionPower.xp, coins: 250),
    Companion(id: 'buho', emoji: '🦉', power: CompanionPower.freeHint, coins: 400),
    Companion(id: 'dragoncito', emoji: '🐉', power: CompanionPower.fireDamage, gems: 8),
    Companion(id: 'hada', emoji: '🧚', power: CompanionPower.shield, gems: 12),
    Companion(id: 'fenix', emoji: '🔥', power: CompanionPower.phoenix, gems: 15),
  ];

  // Cuánto da cada poder (se muestran en la tienda con estos números).
  static const int coinBonusPercent = 25;
  static const int xpBonusPercent = 30;
  static const int fireBonusPercent = 20;
  static const int phoenixHealthPercent = 30;

  static Companion byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.first);

  static CompanionPower powerOf(PlayerProfile? profile) =>
      profile == null ? CompanionPower.none : byId(profile.avatarAccessoryId).power;

  static bool has(PlayerProfile? profile, CompanionPower power) =>
      powerOf(profile) == power;

  /// Monedas con el bonus de la brújula.
  static int coins(PlayerProfile? profile, int base) => has(profile, CompanionPower.coins)
      ? (base * (100 + coinBonusPercent) / 100).round()
      : base;

  /// Experiencia con el bonus del libro.
  static int xp(PlayerProfile? profile, int base) => has(profile, CompanionPower.xp)
      ? (base * (100 + xpBonusPercent) / 100).round()
      : base;

  /// Multiplicador de daño en las peleas (dragoncito).
  static double fightDamage(PlayerProfile? profile) =>
      has(profile, CompanionPower.fireDamage) ? (100 + fireBonusPercent) / 100 : 1.0;
}
