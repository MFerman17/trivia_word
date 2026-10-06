enum LevelType {
  normal,      // Batalla por turnos estándar
  speedRun,    // Modo Relámpago (límite de tiempo)
  survival,    // Oleadas de preguntas
  miniBoss,    // Minijefe al final de capítulo
  worldBoss,   // Jefe Final de Mundo
}

class LevelConfig {
  final int worldId;
  final int chapterId;
  final int levelNumber; // Del 1 al 5 dentro del capítulo
  final int enemyHealth;
  final String title;
  final LevelType type;
  final int targetQuestions; // Cantidad de preguntas para ganar la fase
  final int timeLimitSeconds; // 0 si no hay límite de tiempo
  /// Escala de reto de 1 (introductorio) a 5 (máximo).
  final int difficulty;
  final String enemyName;
  final String enemyEmoji;
  final String enemyAsset;
  final String backgroundAsset;
  final bool isMiniChallenge;
  final int correctAnswersToDefeat;

  LevelConfig({
    required this.worldId,
    required this.chapterId,
    required this.levelNumber,
    required this.title,
    this.type = LevelType.normal,
    this.targetQuestions = 3,
    this.timeLimitSeconds = 0,
    this.enemyHealth = 100,
    this.difficulty = 1,
    this.enemyName = 'Criatura del sendero',
    this.enemyEmoji = '👾',
    this.enemyAsset = 'assets/images/mini_forest_guardian.png',
    this.backgroundAsset = 'assets/images/Bosque_1.png',
    this.isMiniChallenge = false,
    this.correctAnswersToDefeat = 2,
  });
}
