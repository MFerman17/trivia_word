import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';

/// Banco de preguntas definitivo.
///
/// Las preguntas viven en archivos JSON, uno por idioma y dificultad:
///   `assets/questions/IDIOMA/dificultad_N.json` (N de 1 a 5)
/// Así se pueden revisar y corregir sin tocar el código.
///
/// En los archivos la respuesta correcta va SIEMPRE la primera
/// (correctIndex = 0), para que revisarlas sea fácil. Al sacar una pregunta
/// para una partida, las opciones se barajan.
///
/// Para que las preguntas cambien de verdad al avanzar:
///  - Se recuerdan las preguntas ya vistas (en todos los niveles) y no se
///    repiten hasta agotar las de esa dificultad.
///  - Se priorizan las categorías que el jugador ha visto menos últimamente,
///    para que cada nivel mezcle tipos de pregunta distintos.
class QuestionRepository {
  QuestionRepository._();

  static const int minDifficulty = 1;
  static const int maxDifficulty = 5;

  /// Idiomas que tienen banco de preguntas. Al añadir uno nuevo, crear su
  /// carpeta en assets/questions/ y registrarla en pubspec.yaml.
  static const List<String> availableLanguages = ['es'];

  /// Lista cerrada de categorías: id del JSON -> nombre que ve el jugador.
  static const Map<String, String> categoryNames = {
    // Lengua
    'ortografia': 'Ortografía',
    'tildes': 'Tildes',
    'homofonos': 'Homófonos',
    'detectar_error': 'Detecta el error',
    'completar_frase': 'Completa la frase',
    'sinonimos_antonimos': 'Sinónimos y antónimos',
    'significado': 'Significado',
    'refranes': 'Refranes y expresiones',
    // Lógica con palabras
    'analogias': 'Analogías',
    'intruso': 'La palabra intrusa',
    'series': 'Series',
    'anagramas': 'Anagramas',
    'palabra_oculta': 'Palabra oculta',
    'silabas': 'Sílabas',
    'adivinanzas': 'Adivinanzas',
    'deduccion': 'Deducción',
    'problemas': 'Problemas narrados',
    // Apoyo
    'ciencia': 'Ciencia',
    'geografia': 'Geografía',
    'historia': 'Historia',
    'cultura_general': 'Cultura general',
  };

  static const String _seenKeyPrefix = 'seen_questions_';
  static const String _recentCategoriesKeyPrefix = 'recent_categories_';

  /// Cuántas categorías recientes se recuerdan para variar la mezcla.
  static const int _recentCategoryMemory = 30;

  static final Random _random = Random();

  static String _language = 'es';
  static final Map<int, List<Question>> _pools = {};

  /// IDs vistos, en orden (el primero es el más antiguo).
  static final List<String> _seen = [];
  static final List<String> _recentCategories = [];

  static bool get isLoaded => _pools.values.any((pool) => pool.isNotEmpty);

  static int countFor(int difficulty) => _pools[difficulty]?.length ?? 0;

  /// Carga el banco del idioma indicado. Se llama una vez al arrancar la app.
  /// Si algo falla, el juego sigue funcionando con el generador de reserva.
  static Future<void> load({String language = 'es'}) async {
    _language = availableLanguages.contains(language) ? language : 'es';
    _pools.clear();

    for (var difficulty = minDifficulty; difficulty <= maxDifficulty; difficulty++) {
      final path = 'assets/questions/$_language/dificultad_$difficulty.json';
      try {
        final raw = await rootBundle.loadString(path);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final list = (data['questions'] as List)
            .map((item) => _questionFromJson(item as Map<String, dynamic>, difficulty))
            .whereType<Question>()
            .toList();
        _pools[difficulty] = list;
      } catch (error) {
        debugPrint('No se pudo cargar $path: $error');
        _pools[difficulty] = [];
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _seen
        ..clear()
        ..addAll(prefs.getStringList('$_seenKeyPrefix$_language') ?? const []);
      _recentCategories
        ..clear()
        ..addAll(prefs.getStringList('$_recentCategoriesKeyPrefix$_language') ?? const []);
    } catch (error) {
      debugPrint('No se pudo leer el historial de preguntas: $error');
    }

    debugPrint('Banco de preguntas ($_language): '
        '${[for (var d = minDifficulty; d <= maxDifficulty; d++) '$d=${countFor(d)}'].join(', ')}');
  }

  static Question? _questionFromJson(Map<String, dynamic> json, int difficulty) {
    try {
      final categoryId = json['category'] as String;
      return Question(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        options: List<String>.from(json['options'] as List),
        correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
        category: categoryNames[categoryId] ?? categoryId,
        difficulty: difficulty,
        explanation: json['explanation'] as String? ?? '',
        type: QuestionType.values.asNameMap()[json['type']] ??
            QuestionType.multipleChoice,
      );
    } catch (error) {
      debugPrint('Pregunta con formato incorrecto (${json['id']}): $error');
      return null;
    }
  }

  /// Saca [count] preguntas de la dificultad indicada para una partida.
  ///
  /// [exclude] son IDs que no deben salir (las que ya hay en la partida).
  /// [preferCategory], si se indica, se elige primero (para los reemplazos
  /// del monstruo, que conservan la categoría de la pregunta fallada).
  static List<Question> draw({
    required int difficulty,
    required int count,
    Set<String> exclude = const {},
    String? preferCategory,
  }) {
    final pool = _pools[difficulty.clamp(minDifficulty, maxDifficulty)] ?? const [];
    if (pool.isEmpty || count <= 0) return [];

    var candidates = pool
        .where((q) => !exclude.contains(q.id) && !_seen.contains(q.id))
        .toList();

    // Si quedan pocas sin ver, se "olvidan" las vistas de esta dificultad
    // (salvo las de la partida actual) y se vuelve a empezar el ciclo.
    if (candidates.length < count) {
      final poolIds = pool.map((q) => q.id).toSet();
      _seen.removeWhere(poolIds.contains);
      candidates = pool.where((q) => !exclude.contains(q.id)).toList();
    }

    final picked = <Question>[];
    final usedCategories = <String>[];
    while (picked.length < count && candidates.isNotEmpty) {
      final category = picked.isEmpty && preferCategory != null &&
              candidates.any((q) => q.category == preferCategory)
          ? preferCategory
          : _leastRecentCategory(candidates, usedCategories);
      final options = candidates.where((q) => q.category == category).toList();
      final question = options[_random.nextInt(options.length)];
      candidates.remove(question);
      picked.add(question);
      usedCategories.add(category);
    }

    _remember(picked);
    return picked.map(_shuffled).toList();
  }

  /// Elige la categoría menos vista últimamente entre las disponibles.
  /// En caso de empate, una al azar.
  static String _leastRecentCategory(
    List<Question> candidates,
    List<String> usedInThisDraw,
  ) {
    final history = [..._recentCategories, ...usedInThisDraw];
    int score(String category) {
      var total = 0;
      for (var i = 0; i < history.length; i++) {
        // Lo más reciente pesa más que lo antiguo.
        if (history[i] == category) total += i + 1;
      }
      return total;
    }

    final categories = candidates.map((q) => q.category).toSet().toList()..shuffle(_random);
    categories.sort((a, b) => score(a).compareTo(score(b)));
    return categories.first;
  }

  static void _remember(List<Question> picked) {
    if (picked.isEmpty) return;
    for (final question in picked) {
      _seen.remove(question.id);
      _seen.add(question.id);
      _recentCategories.add(question.category);
    }
    final totalQuestions = _pools.values.fold<int>(0, (sum, pool) => sum + pool.length);
    while (_seen.length > totalQuestions) {
      _seen.removeAt(0);
    }
    while (_recentCategories.length > _recentCategoryMemory) {
      _recentCategories.removeAt(0);
    }
    _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_seenKeyPrefix$_language', List.of(_seen));
      await prefs.setStringList(
          '$_recentCategoriesKeyPrefix$_language', List.of(_recentCategories));
    } catch (error) {
      debugPrint('No se pudo guardar el historial de preguntas: $error');
    }
  }

  /// Baraja las opciones y recalcula cuál es la correcta.
  static Question _shuffled(Question question) {
    final correct = question.options[question.correctIndex];
    final options = List<String>.of(question.options)..shuffle(_random);
    return Question(
      id: question.id,
      worldId: question.worldId,
      chapterId: question.chapterId,
      prompt: question.prompt,
      options: options,
      correctIndex: options.indexOf(correct),
      category: question.category,
      difficulty: question.difficulty,
      explanation: question.explanation,
      type: question.type,
    );
  }
}
