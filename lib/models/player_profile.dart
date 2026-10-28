import 'dart:convert';

class PlayerProfile {
  String name;
  int level;
  int experience;
  int coins;
  int gems;
  int healthPotions;
  int letterHints;
  int totalStars;
  DateTime? lastDailyReward; // 👈 Campo para controlar el tiempo del cofre

  // Cosmetics are visual only; these fields are persisted with the local profile.
  String avatarCharacterId;
  String avatarFrameId;
  String avatarAccessoryId;
  List<String> ownedAvatarCharacters;
  List<String> ownedAvatarFrames;
  List<String> ownedAvatarAccessories;

  /// Nivel de cada mejora de luchador (ver FighterService): health, power, super.
  Map<String, int> fighterUpgrades;

  /// País del jugador (código ISO de 2 letras, p. ej. "ES"). Vacío = aún no
  /// eligió alias y país: el juego le muestra la pantalla de bienvenida.
  String country;

  bool get needsWelcome => country.isEmpty;

  PlayerProfile({
    this.name = 'Jugador 1',
    this.level = 1,
    this.experience = 0,
    this.coins = 100,
    this.gems = 10,
    this.healthPotions = 1,
    this.letterHints = 2,
    this.totalStars = 0,
    this.lastDailyReward,
    this.avatarCharacterId = 'explorador',
    this.avatarFrameId = 'basico',
    this.avatarAccessoryId = 'ninguno',
    List<String>? ownedAvatarCharacters,
    List<String>? ownedAvatarFrames,
    List<String>? ownedAvatarAccessories,
    Map<String, int>? fighterUpgrades,
    this.country = '',
  })  : fighterUpgrades = fighterUpgrades ?? {},
        ownedAvatarCharacters = ownedAvatarCharacters ?? ['explorador'],
        ownedAvatarFrames = ownedAvatarFrames ?? ['basico'],
        ownedAvatarAccessories =
            ownedAvatarAccessories ?? ['ninguno'];

  // Verifica si han pasado al menos 24 horas desde la última recolección
  bool get canClaimDailyReward {
    if (lastDailyReward == null) return true;
    final now = DateTime.now();
    final difference = now.difference(lastDailyReward!);
    return difference.inHours >= 24;
  }

  // Mantenemos el nombre original para evitar errores en otras pantallas
  int get maxExperienceForCurrentLevel => level * 100;

  // Porcentaje de progreso dentro del nivel actual (de 0.0 a 1.0)
  double get levelProgress {
    if (maxExperienceForCurrentLevel == 0) return 0.0;
    return (experience / maxExperienceForCurrentLevel).clamp(0.0, 1.0);
  }

  // Método para añadir XP y subir de nivel automáticamente
  void addExperience(int amount) {
    experience += amount;
    while (experience >= maxExperienceForCurrentLevel) {
      experience -= maxExperienceForCurrentLevel;
      level++;
    }
  }

  // Método para sumar estrellas
  void addStars(int count) {
    totalStars += count;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'level': level,
      'experience': experience,
      'coins': coins,
      'gems': gems,
      'healthPotions': healthPotions,
      'letterHints': letterHints,
      'totalStars': totalStars,
      'lastDailyReward': lastDailyReward?.toIso8601String(),
      'avatarCharacterId': avatarCharacterId,
      'avatarFrameId': avatarFrameId,
      'avatarAccessoryId': avatarAccessoryId,
      'ownedAvatarCharacters': ownedAvatarCharacters,
      'ownedAvatarFrames': ownedAvatarFrames,
      'ownedAvatarAccessories': ownedAvatarAccessories,
      // Solo se guarda si hay alguna mejora comprada. Así los jugadores sin
      // mejoras siguen guardando en la nube aunque las reglas de Firestore
      // aún no conozcan este campo.
      if (fighterUpgrades.values.any((level) => level > 0))
        'fighterUpgrades': fighterUpgrades,
      if (country.isNotEmpty) 'country': country,
    };
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      name: map['name'] ?? 'Jugador 1',
      level: map['level'] ?? 1,
      experience: map['experience'] ?? 0,
      coins: map['coins'] ?? 100,
      gems: map['gems'] ?? 10,
      healthPotions: map['healthPotions'] ?? 1,
      letterHints: map['letterHints'] ?? 2,
      totalStars: map['totalStars'] ?? 0,
      lastDailyReward: map['lastDailyReward'] != null
          ? DateTime.tryParse(map['lastDailyReward'])
          : null,
      avatarCharacterId: map['avatarCharacterId'] ?? 'explorador',
      avatarFrameId: map['avatarFrameId'] ?? 'basico',
      avatarAccessoryId: map['avatarAccessoryId'] ?? 'ninguno',
      ownedAvatarCharacters: _readStringList(
        map['ownedAvatarCharacters'],
        fallback: const ['explorador'],
      ),
      ownedAvatarFrames: _readStringList(
        map['ownedAvatarFrames'],
        fallback: const ['basico'],
      ),
      ownedAvatarAccessories: _readStringList(
        map['ownedAvatarAccessories'],
        fallback: const ['ninguno'],
      ),
      fighterUpgrades: _readIntMap(map['fighterUpgrades']),
      country: map['country'] is String ? map['country'] as String : '',
    );
  }

  String toJson() => json.encode(toMap());

  factory PlayerProfile.fromJson(String source) =>
      PlayerProfile.fromMap(json.decode(source));
}

List<String> _readStringList(dynamic value, {required List<String> fallback}) {
  if (value is! List) return List<String>.from(fallback);
  return value.whereType<String>().toList();
}

Map<String, int> _readIntMap(dynamic value) {
  if (value is! Map) return {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}
