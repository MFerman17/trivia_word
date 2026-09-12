class StageProgress {
  final int worldId;
  final int chapterId;
  final int levelNumber;
  final int stars;
  final int highScore;
  final bool isUnlocked;

  StageProgress({
    required this.worldId,
    required this.chapterId,
    required this.levelNumber,
    this.stars = 0,
    this.highScore = 0,
    this.isUnlocked = false,
  });

  /// Clave única estandarizada para SharedPreferences: w1_c1_l1
  String get stageKey => 'w${worldId}_c${chapterId}_l$levelNumber';

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'worldId': worldId,
      'chapterId': chapterId,
      'levelNumber': levelNumber,
      'stars': stars,
      'highScore': highScore,
      'isUnlocked': isUnlocked,
    };
  }

  /// Crear desde JSON
  factory StageProgress.fromJson(Map<String, dynamic> json) {
    return StageProgress(
      worldId: json['worldId'] as int? ?? 1,
      chapterId: json['chapterId'] as int? ?? 1,
      levelNumber: json['levelNumber'] as int? ?? 1,
      stars: json['stars'] as int? ?? 0,
      highScore: json['highScore'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
    );
  }
}