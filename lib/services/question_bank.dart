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
  static List<Question> getQuestionsForLevel(int world, int chapter, int level) {
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
      ),
      Question(
        id: 'def_2',
        prompt: '¿Cuál de las siguientes palabras es un sustantivo?',
        options: ['Correr', 'Rápido', 'Bosque', 'Ayer'],
        correctIndex: 2,
        category: 'Lengua',
      ),
      Question(
        id: 'def_3',
        prompt: '¿Cuál es el planeta más grande del sistema solar?',
        options: ['Marte', 'Saturno', 'Júpiter', 'Neptuno'],
        correctIndex: 2,
        category: 'Ciencia',
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
      ),
      Question(
        id: 'w1_2',
        prompt: '¿Cuánto es 8 x 7?',
        options: ['54', '56', '64', '49'],
        correctIndex: 1,
        category: 'Matemáticas',
      ),
      Question(
        id: 'w1_3',
        prompt: '¿Cuál es el símbolo químico del Agua?',
        options: ['CO2', 'O2', 'H2O', 'NaCl'],
        correctIndex: 2,
        category: 'Ciencia',
      ),
    ];
  }
}