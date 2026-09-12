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
  final int levelNumber; // Del 1 al 10 dentro del capítulo
  final int enemyHealth;
  final String title;
  final LevelType type;
  final int targetQuestions; // Cantidad de preguntas para ganar la fase
  final int timeLimitSeconds; // 0 si no hay límite de tiempo

  LevelConfig({
    required this.worldId,
    required this.chapterId,
    required this.levelNumber,
    required this.title,
    this.type = LevelType.normal,
    this.targetQuestions = 3,
    this.timeLimitSeconds = 0,
    this.enemyHealth = 100,
  });
}