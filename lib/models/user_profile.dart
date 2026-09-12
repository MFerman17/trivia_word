class UserProfile {
  final String username;
  final String avatarUrl;
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final int totalGamesPlayed;
  final int gamesWon;
  final int winStreak;
  final int highestStreak;
  final List<String> unlockedTitles;
  final String activeTitle;

  UserProfile({
    required this.username,
    required this.avatarUrl,
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
    required this.totalGamesPlayed,
    required this.gamesWon,
    required this.winStreak,
    required this.highestStreak,
    required this.unlockedTitles,
    required this.activeTitle,
  });

  // Porcentaje de victorias para la gráfica / estadística
  double get winRate =>
      totalGamesPlayed == 0 ? 0.0 : (gamesWon / totalGamesPlayed) * 100;

  // Porcentaje de progreso de nivel
  double get xpProgress => currentXp / nextLevelXp;

  // Datos simulados por defecto del usuario
  factory UserProfile.defaultProfile() {
    return UserProfile(
      username: 'JugadorTrivia',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
      level: 14,
      currentXp: 750,
      nextLevelXp: 1000,
      totalGamesPlayed: 128,
      gamesWon: 89,
      winStreak: 5,
      highestStreak: 12,
      unlockedTitles: [
        'Novato',
        'Cazador de Palabras',
        'Estratega',
        'Maestro del Vocabulario'
      ],
      activeTitle: 'Cazador de Palabras',
    );
  }
}