import '../models/level_config.dart';
import '../models/question.dart';
import 'procedural_question_service.dart';

class QuestionBank {
  /// La dificultad sube dentro de cada capítulo y también al avanzar de
  /// mundo. El último nivel de cada mundo es su jefe.
  static LevelConfig getConfigForLevel(int world, int chapter, int level) {
    // La dificultad sube también dentro de cada capítulo, no solo al cambiar
    // de mundo: los niveles 1–2, 3–4 y 5 forman tres escalones.
    final difficulty =
        (world + chapter + (level - 1) ~/ 2 - 1).clamp(1, 5).toInt();
    final isWorldBoss = chapter == 3 && level == 5;
    final isChapterBoss = level == 5 && !isWorldBoss;

    final type = isWorldBoss
        ? LevelType.worldBoss
        : isChapterBoss
        ? LevelType.miniBoss
        : LevelType.normal;

    final enemyName = isWorldBoss
        ? _worldBossName(world)
        : isChapterBoss
        ? 'Guardián del capítulo'
        : 'Criatura del sendero';

    return LevelConfig(
      title: 'Mundo $world - Fase $chapter.$level',
      worldId: world,
      chapterId: chapter,
      levelNumber: level,
      type: type,
      difficulty: difficulty,
      enemyName: enemyName,
      enemyEmoji: isWorldBoss ? '🐉' : isChapterBoss ? '👹' : '👾',
      enemyAsset: worldCreatureAsset(world),
      backgroundAsset: worldBackgroundAsset(world, chapter),
      enemyHealth: isWorldBoss
          ? 180
          : isChapterBoss
          ? 120
          : 70 + difficulty * 10,
      targetQuestions: isWorldBoss ? 10 : isChapterBoss ? 8 : 6,
      correctAnswersToDefeat: isWorldBoss ? 10 : isChapterBoss ? 8 : 6,
    );
  }

  /// Encuentro lateral: criatura menos resistente y recompensa limitada.
  static LevelConfig getConfigForMiniChallenge(int world, int challenge) {
    final difficulty = (world + challenge - 1).clamp(1, 5).toInt();
    const enemiesByWorld = [
      ['Guardián del Bosque', 'Duende del Musgo', 'Espíritu de Raíces'],
      ['Murciélago de Cristal', 'Eco de la Caverna', 'Rastreador de Piedra'],
      ['Familiar de las Islas', 'Duende de Nube', 'Vigía del Viento'],
      ['Salamandra de Lava', 'Espíritu de Brasa', 'Cría de Magma'],
    ];
    const emojisByWorld = ['🧌', '🦇', '🪽', '🦎'];
    final worldIndex = (world - 1).clamp(0, 3).toInt();
    final challengeIndex = (challenge - 1).clamp(0, 2).toInt();

    return LevelConfig(
      title: 'Mini-reto $challenge · Mundo $world',
      worldId: world,
      chapterId: 1,
      levelNumber: challenge,
      type: LevelType.normal,
      difficulty: difficulty,
      enemyName: enemiesByWorld[worldIndex][challengeIndex],
      enemyEmoji: emojisByWorld[worldIndex],
      enemyAsset: worldCreatureAsset(world),
      backgroundAsset: worldBackgroundAsset(world, 1),
      enemyHealth: 60,
      targetQuestions: 4,
      isMiniChallenge: true,
      correctAnswersToDefeat: 4,
    );
  }

  static String worldCreatureAsset(int world) => switch (world) {
    1 => 'assets/images/mini_forest_guardian.png',
    2 => 'assets/images/mini_cave_bat.png',
    3 => 'assets/images/mini_sky_familiar.png',
    4 => 'assets/images/mini_lava_salamander.png',
    _ => 'assets/images/mini_forest_guardian.png',
  };

  static String worldBackgroundAsset(int world, int chapter) {
    final chapterNumber = chapter.clamp(1, 3).toInt();
    return switch (world) {
      1 => 'assets/images/Bosque_$chapterNumber.png',
      2 => 'assets/images/Cavernas_$chapterNumber.png',
      3 => 'assets/images/Islas_$chapterNumber.png',
      4 => 'assets/images/Volcan_$chapterNumber.png',
      _ => 'assets/images/Bosque_1.png',
    };
  }

  static String _worldBossName(int world) => switch (world) {
    1 => 'Dragón del Bosque',
    2 => 'Coloso de las Cavernas',
    3 => 'Señor de las Islas',
    4 => 'Titán del Volcán',
    _ => 'Guardián del Mundo',
  };

  /// Obtiene la lista de preguntas según el mundo, capítulo y nivel
  static List<Question> getQuestionsForLevel(
    int world,
    int chapter,
    int level,
  ) {
    final config = getConfigForLevel(world, chapter, level);
    final encounterIndex = (world - 1) * 15 + (chapter - 1) * 5 + level - 1;
    final curated = _curatedQuestionForEncounter(
      encounterIndex,
      config.difficulty,
    );
    final generated = ProceduralQuestionService.forEncounter(
      world: world,
      chapter: chapter,
      level: level,
      difficulty: config.difficulty,
      count: config.targetQuestions - (curated == null ? 0 : 1),
    );
    if (curated == null) return generated;
    return [curated, ...generated];
  }

  static List<Question> getQuestionsForMiniChallenge(
    int world,
    int challenge,
  ) {
    final config = getConfigForMiniChallenge(world, challenge);
    return ProceduralQuestionService.forEncounter(
      world: world,
      chapter: 1,
      level: challenge,
      difficulty: config.difficulty,
      count: config.targetQuestions,
      isMiniChallenge: true,
    );
  }

  /// Añade una pregunta cuando el jugador agotó las iniciales sin derrotar
  /// al enemigo. El combate continúa hasta conseguir los aciertos necesarios.
  static Question? getAdditionalQuestion({
    required int world,
    required int chapter,
    required int level,
    required int questionIndex,
    required int difficulty,
    required bool isMiniChallenge,
  }) {
    final generated = ProceduralQuestionService.forEncounter(
      world: world,
      chapter: chapter,
      level: level,
      difficulty: difficulty,
      count: questionIndex + 1,
      isMiniChallenge: isMiniChallenge,
    );
    return generated.isEmpty ? null : generated.last;
  }

  /// Busca una pregunta nueva para una penalización del monstruo, conservando
  /// categoría y dificultad. Solo se usan preguntas no vistas en el encuentro.
  static Question? getReplacementQuestion({
    required Question original,
    required int world,
    required int chapter,
    required int level,
    required bool isMiniChallenge,
    required Set<String> usedQuestionIds,
  }) {
    final generated = ProceduralQuestionService.forEncounter(
      world: world,
      chapter: chapter,
      level: level,
      difficulty: original.difficulty,
      count: 96,
      isMiniChallenge: isMiniChallenge,
      increaseDifficulty: false,
    );
    final curated = [
      ..._getDefaultQuestions(),
      ..._getStarterQuestions(),
      ..._getProgressionQuestions(),
    ];
    final candidates = [...generated, ...curated];

    for (final candidate in candidates) {
      if (candidate.difficulty == original.difficulty &&
          candidate.category == original.category &&
          !usedQuestionIds.contains(candidate.id) &&
          candidate.prompt != original.prompt) {
        return candidate;
      }
    }
    return null;
  }

  /// Cada pregunta escrita a mano se asigna una sola vez al primer encuentro
  /// disponible de su dificultad; el resto se genera con valores propios.
  static Question? _curatedQuestionForEncounter(
    int encounterIndex,
    int difficulty,
  ) {
    final allQuestions = [
      ..._getDefaultQuestions(),
      ..._getStarterQuestions(),
      ..._getProgressionQuestions(),
    ];
    final matching = allQuestions
        .where((question) => question.difficulty == difficulty)
        .toList();
    var previousEncountersAtDifficulty = 0;
    for (var index = 0; index < encounterIndex; index++) {
      final previousWorld = index ~/ 15 + 1;
      final withinWorld = index % 15;
      final previousChapter = withinWorld ~/ 5 + 1;
      final previousLevel = withinWorld % 5 + 1;
      if (getConfigForLevel(previousWorld, previousChapter, previousLevel)
              .difficulty ==
          difficulty) {
        previousEncountersAtDifficulty++;
      }
    }
    if (previousEncountersAtDifficulty >= matching.length) return null;
    return matching[previousEncountersAtDifficulty];
  }

  /// Preguntas por defecto
  static List<Question> _getDefaultQuestions() {
    return [
      Question(
        id: 'def_1',
        prompt: '¿Cuál es el resultado de 15 + 27?',
        options: ['32', '42', '52', '40'],
        correctIndex: 1,
        category: 'Matemáticas',
        difficulty: 1,
        explanation:
            'Al sumar 15 + 27, las unidades dan 12: escribimos 2 y llevamos 1. Luego 1 + 2 + 1 = 4. El resultado es 42.',
      ),
      Question(
        id: 'def_2',
        prompt: '¿Cuál de las siguientes palabras es un sustantivo?',
        options: ['Correr', 'Rápido', 'Bosque', 'Ayer'],
        correctIndex: 2,
        category: 'Lengua',
        difficulty: 1,
        explanation:
            'Un sustantivo nombra personas, animales, lugares, cosas o ideas. “Bosque” nombra un lugar.',
      ),
      Question(
        id: 'def_3',
        prompt: '¿Cuál es el planeta más grande del sistema solar?',
        options: ['Marte', 'Saturno', 'Júpiter', 'Neptuno'],
        correctIndex: 2,
        category: 'Ciencia',
        difficulty: 1,
        explanation:
            'Júpiter es el planeta más grande del sistema solar. Es un gigante gaseoso y tiene más volumen que todos los demás planetas.',
      ),
    ];
  }

  /// Preguntas introductorias de varias categorías.
  static List<Question> _getStarterQuestions() {
    return [
      Question(
        id: 'starter_grammar',
        prompt: '¿Qué tipo de palabra es "rápidamente"?',
        options: ['Sustantivo', 'Adjetivo', 'Adverbio', 'Verbo'],
        correctIndex: 2,
        category: 'Gramática',
        difficulty: 2,
        explanation:
            '“Rápidamente” es un adverbio de modo: explica cómo ocurre una acción. Muchos adverbios de modo terminan en “-mente”.',
      ),
      Question(
        id: 'starter_multiplication',
        prompt: '¿Cuánto es 8 x 7?',
        options: ['54', '56', '64', '49'],
        correctIndex: 1,
        category: 'Matemáticas',
        difficulty: 1,
        explanation:
            '8 × 7 significa sumar ocho grupos de siete. También puedes recordar que 7 × 8 = 56.',
      ),
      Question(
        id: 'starter_water_formula',
        prompt: '¿Cuál es el símbolo químico del Agua?',
        options: ['CO2', 'O2', 'H2O', 'NaCl'],
        correctIndex: 2,
        category: 'Ciencia',
        difficulty: 1,
        explanation:
            'Cada molécula de agua tiene dos átomos de hidrógeno (H) y uno de oxígeno (O); por eso su fórmula es H₂O.',
      ),
    ];
  }

  /// Preguntas generales de dificultad creciente. Las explicaciones están
  /// pensadas para enseñar el razonamiento, no solo revelar la respuesta.
  static List<Question> _getProgressionQuestions() => [
    Question(
      id: 'd2_division',
      prompt: '¿Cuánto es 24 ÷ 6?',
      options: ['3', '4', '6', '18'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 2,
      explanation: '24 ÷ 6 pregunta cuántos grupos de 6 caben en 24. Como 6 × 4 = 24, el resultado es 4.',
    ),
    Question(
      id: 'd2_verb',
      prompt: 'En la oración «Los niños cantaban», ¿cuál es el verbo?',
      options: ['Los', 'niños', 'cantaban', 'oración'],
      correctIndex: 2,
      category: 'Lengua',
      difficulty: 2,
      explanation: 'El verbo expresa la acción. «Cantaban» indica lo que hacían los niños.',
    ),
    Question(
      id: 'd2_fraction',
      prompt: '¿Cuánto es la mitad de 18?',
      options: ['8', '9', '10', '12'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 2,
      explanation: 'La mitad se obtiene dividiendo entre 2: 18 ÷ 2 = 9.',
    ),
    Question(
      id: 'd2_multiplication',
      prompt: '¿Qué número falta? 6 × ___ = 54',
      options: ['7', '8', '9', '10'],
      correctIndex: 2,
      category: 'Matemáticas',
      difficulty: 2,
      explanation: '54 ÷ 6 = 9; por eso 6 × 9 = 54.',
    ),
    Question(
      id: 'd3_fraction',
      prompt: '¿Cuánto es 3/4 de 20?',
      options: ['5', '10', '15', '16'],
      correctIndex: 2,
      category: 'Matemáticas',
      difficulty: 3,
      explanation: 'Primero 20 ÷ 4 = 5. Luego 5 × 3 = 15.',
    ),
    Question(
      id: 'd3_moon',
      prompt: '¿Por qué podemos ver la Luna iluminada desde la Tierra?',
      options: ['Produce luz como una estrella', 'Refleja la luz del Sol', 'La ilumina el núcleo terrestre', 'Tiene fuego en su superficie'],
      correctIndex: 1,
      category: 'Ciencia',
      difficulty: 3,
      explanation: 'La Luna no produce luz visible propia: refleja hacia nosotros parte de la luz que recibe del Sol.',
    ),
    Question(
      id: 'd3_time',
      prompt: '¿Cuántos minutos hay en 2 horas y media?',
      options: ['120', '130', '150', '250'],
      correctIndex: 2,
      category: 'Matemáticas',
      difficulty: 3,
      explanation: 'Dos horas son 120 minutos y media hora son 30; 120 + 30 = 150.',
    ),
    Question(
      id: 'd3_triangle',
      prompt: 'Dos ángulos de un triángulo miden 60° y 70°. ¿Cuánto mide el tercero?',
      options: ['40°', '50°', '60°', '70°'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 3,
      explanation: 'Los ángulos interiores de un triángulo suman 180°. Entonces 180° − 60° − 70° = 50°.',
    ),
    Question(
      id: 'd3_decimal',
      prompt: '¿Qué fracción representa 0,5?',
      options: ['1/5', '1/2', '2/5', '5/100'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 3,
      explanation: '0,5 representa cinco décimas. Al simplificar 5/10 dividiendo arriba y abajo entre 5, obtenemos 1/2.',
    ),
    Question(
      id: 'd4_percent',
      prompt: 'Una mochila cuesta 80 monedas y tiene 25% de descuento. ¿Cuántas monedas descuentan?',
      options: ['10', '20', '25', '60'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 4,
      explanation: '25% equivale a una cuarta parte. 80 ÷ 4 = 20 monedas de descuento.',
    ),
    Question(
      id: 'd4_ecosystem',
      prompt: 'En una cadena alimentaria, ¿qué organismo suele producir su propio alimento?',
      options: ['El zorro', 'La seta', 'La planta', 'El conejo'],
      correctIndex: 2,
      category: 'Ciencia',
      difficulty: 4,
      explanation: 'Las plantas son productoras: usan la energía de la luz para fabricar nutrientes mediante la fotosíntesis.',
    ),
    Question(
      id: 'd4_fraction_sum',
      prompt: '¿Cuánto es 3/5 + 1/5?',
      options: ['4/10', '4/5', '3/10', '1'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 4,
      explanation: 'Como los denominadores son iguales, se suman los numeradores: 3 + 1 = 4. El resultado es 4/5.',
    ),
    Question(
      id: 'd4_inference',
      prompt: '«El cielo se oscureció y Ana abrió su paraguas». ¿Qué es lo más probable?',
      options: ['Empezará a nevar', 'Ana espera lluvia', 'Ana va a nadar', 'Ya salió el Sol'],
      correctIndex: 1,
      category: 'Comprensión lectora',
      difficulty: 4,
      explanation: 'El cielo oscuro y el paraguas son pistas que permiten inferir que Ana espera lluvia.',
    ),
    Question(
      id: 'd4_division',
      prompt: 'Una caja con 360 cartas se reparte por igual entre 9 equipos. ¿Cuántas recibe cada equipo?',
      options: ['30', '40', '45', '60'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 4,
      explanation: 'Hay que dividir 360 entre 9. Como 9 × 40 = 360, cada equipo recibe 40 cartas.',
    ),
    Question(
      id: 'd5_area',
      prompt: 'Un rectángulo mide 12 cm de largo y 7 cm de ancho. ¿Cuál es su área?',
      options: ['19 cm²', '38 cm²', '84 cm²', '96 cm²'],
      correctIndex: 2,
      category: 'Matemáticas',
      difficulty: 5,
      explanation: 'El área de un rectángulo es largo × ancho: 12 × 7 = 84 cm².',
    ),
    Question(
      id: 'd5_condensation',
      prompt: '¿Qué cambio ocurre cuando el vapor de agua se enfría y forma gotitas?',
      options: ['Evaporación', 'Condensación', 'Fusión', 'Congelación'],
      correctIndex: 1,
      category: 'Ciencia',
      difficulty: 5,
      explanation: 'En la condensación, el vapor pierde calor y pasa al estado líquido, formando pequeñas gotas.',
    ),
    Question(
      id: 'd5_equivalent_fraction',
      prompt: '¿Qué fracción es equivalente a 3/4?',
      options: ['6/10', '9/12', '12/20', '12/24'],
      correctIndex: 1,
      category: 'Matemáticas',
      difficulty: 5,
      explanation: 'Al multiplicar numerador y denominador de 3/4 por 3 se obtiene 9/12; ambas fracciones representan la misma cantidad.',
    ),
    Question(
      id: 'd5_ratio',
      prompt: 'Por cada 3 pociones se usan 4 cristales. ¿Cuántos cristales hacen falta para 9 pociones?',
      options: ['9', '12', '15', '36'],
      correctIndex: 1,
      category: 'Razonamiento',
      difficulty: 5,
      explanation: '9 pociones son 3 veces 3 pociones. Multiplicamos también los cristales por 3: 4 × 3 = 12.',
    ),
    Question(
      id: 'd5_multi_step',
      prompt: 'Leo tenía 120 monedas, gastó 1/3 y después ganó 25. ¿Cuántas tiene ahora?',
      options: ['65', '80', '105', '145'],
      correctIndex: 2,
      category: 'Razonamiento',
      difficulty: 5,
      explanation: 'Un tercio de 120 es 40. Tras gastar 40 quedan 80; al sumar las 25 ganadas obtiene 105.',
    ),
  ];
}
