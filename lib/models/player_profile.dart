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
  });

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
    );
  }

  String toJson() => json.encode(toMap());

  factory PlayerProfile.fromJson(String source) =>
      PlayerProfile.fromMap(json.decode(source));
}