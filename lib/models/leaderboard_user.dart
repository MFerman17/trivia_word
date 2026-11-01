class LeaderboardUser {
  final int rank;
  final String name;
  final String countryFlag;
  final int trophies;
  final String avatarEmoji;

  /// Copas ganadas en el torneo semanal.
  final int cups;

  LeaderboardUser({
    this.cups = 0,
    required this.rank,
    required this.name,
    required this.countryFlag,
    required this.trophies,
    required this.avatarEmoji,
  });
}