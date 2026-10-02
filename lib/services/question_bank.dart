import '../models/level_config.dart';
import '../models/question.dart';

class QuestionBank {
  /// Obtiene la configuración específica de un nivel (salud del enemigo, título, etc.)
  static LevelConfig getConfigForLevel(int world, int chapter, int level) {
    return LevelConfig(
      title: 'Mundo $world - Fase $chapter.$level',
      worldId: world,
      chapterId: chapter,
      levelNumber: level,
      enemyHealth: 100 + (level * 10),
    );
  }

  /// Obtiene la lista de preguntas según el mundo, capítulo y nivel
  static List<Question> getQuestionsForLevel(
    int world,
    int chapter,
    int level,
  ) {
    switch (world) {
      case 1:
        return _getWorld1Questions(level);
      default:
        return _getDefaultQuestions();
    }
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

  /// Preguntas para el Mundo 1
  static List<Question> _getWorld1Questions(int level) {
    return [
      Question(
        id: 'w1_1',
        prompt: '¿Qué tipo de palabra es "rápidamente"?',
        options: ['Sustantivo', 'Adjetivo', 'Adverbio', 'Verbo'],
        correctIndex: 2,
        category: 'Gramática',
        difficulty: 2,
        explanation:
            '“Rápidamente” es un adverbio de modo: explica cómo ocurre una acción. Muchos adverbios de modo terminan en “-mente”.',
      ),
      Question(
        id: 'w1_2',
        prompt: '¿Cuánto es 8 x 7?',
        options: ['54', '56', '64', '49'],
        correctIndex: 1,
        category: 'Matemáticas',
        difficulty: 1,
        explanation:
            '8 × 7 significa sumar ocho grupos de siete. También puedes recordar que 7 × 8 = 56.',
      ),
      Question(
        id: 'w1_3',
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
}
