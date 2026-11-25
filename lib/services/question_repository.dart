import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
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
///  - Se cuenta cuántas veces ha salido cada pregunta, y NINGUNA sale más
///    de 2 veces mientras queden otras ([maxShows]).
///  - Orden de preferencia al elegir:
///      1. Nunca vistas de la dificultad del nivel.
///      2. Nunca vistas de las 2 dificultades siguientes (así, si se acaban,
///         el jugador nota que sube el nivel en vez de ver repeticiones).
///      3. Vistas una sola vez, empezando por las más antiguas.
///      4. Solo si el banco entero ya salió 2 veces: las menos recientes.
///  - Se priorizan las categorías que el jugador ha visto menos últimamente,
///    para que cada nivel mezcle tipos de pregunta distintos.
class QuestionRepository {
  QuestionRepository._();

  static const int minDifficulty = 1;
  static const int maxDifficulty = 5;

  /// Idiomas que tienen banco de preguntas. Al añadir uno nuevo, crear su
  /// carpeta en assets/questions/ y registrarla en pubspec.yaml.
  static const List<String> availableLanguages = ['es', 'en'];

  /// Lista cerrada de categorías: id del JSON -> nombre en español.
  /// El nombre que ve el jugador sale de los .arb (ver [categoryName]).
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
    'matematicas': 'Matemáticas',
    // Apoyo
    'ciencia': 'Ciencia',
    'geografia': 'Geografía',
    'historia': 'Historia',
    'cultura_general': 'Cultura general',
    'arte': 'Arte',
  };

  /// Nombre de la categoría en el idioma del banco cargado.
  /// (Se usa el idioma del banco y no el de la pantalla porque al cambiar de
  /// idioma el banco se recarga un instante antes de redibujar la app.)
  static String categoryName(String id) {
    final l = lookupAppLocalizations(Locale(_language));
    return switch (id) {
      'ortografia' => l.catOrtografia,
      'tildes' => l.catTildes,
      'homofonos' => l.catHomofonos,
      'detectar_error' => l.catDetectarError,
      'completar_frase' => l.catCompletarFrase,
      'sinonimos_antonimos' => l.catSinonimosAntonimos,
      'significado' => l.catSignificado,
      'refranes' => l.catRefranes,
      'analogias' => l.catAnalogias,
      'intruso' => l.catIntruso,
      'series' => l.catSeries,
      'anagramas' => l.catAnagramas,
      'palabra_oculta' => l.catPalabraOculta,
      'silabas' => l.catSilabas,
      'adivinanzas' => l.catAdivinanzas,
      'deduccion' => l.catDeduccion,
      'problemas' => l.catProblemas,
      'ciencia' => l.catCiencia,
      'geografia' => l.catGeografia,
      'historia' => l.catHistoria,
      'cultura_general' => l.catCulturaGeneral,
      'matematicas' => l.catMatematicas,
      'arte' => l.catArte,
      _ => categoryNames[id] ?? id,
    };
  }

  static const String _seenKeyPrefix = 'seen_questions_';
  static const String _shownKeyPrefix = 'shown_counts_';

  /// Veces máximas que sale una pregunta mientras queden otras sin agotar.
  static const int maxShows = 2;

  /// Cuántas dificultades por encima se miran antes de repetir.
  static const int _harderSteps = 2;
  static const String _recentCategoriesKeyPrefix = 'recent_categories_';

  /// Cuántas categorías recientes se recuerdan para variar la mezcla.
  static const int _recentCategoryMemory = 30;

  static final Random _random = Random();

  static String _language = 'es';
  static final Map<int, List<Question>> _pools = {};

  /// IDs vistos, en orden (el primero es el más antiguo). Sirve para saber
  /// qué pregunta se vio hace más tiempo.
  static final List<String> _seen = [];

  /// Veces que ha salido cada pregunta (por ID).
  static final Map<String, int> _shown = {};

  static int timesShown(String id) => _shown[id] ?? 0;
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
      _shown.clear();
      final counts = prefs.getStringList('$_shownKeyPrefix$_language');
      if (counts == null) {
        // Partida de antes de contar: lo ya visto cuenta como 1 vez.
        for (final id in _seen) {
          _shown[id] = 1;
        }
      } else {
        for (final entry in counts) {
          final cut = entry.lastIndexOf('=');
          if (cut <= 0) continue;
          _shown[entry.substring(0, cut)] = int.tryParse(entry.substring(cut + 1)) ?? 1;
        }
      }
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
        category: categoryName(categoryId),
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
    final base = difficulty.clamp(minDifficulty, maxDifficulty).toInt();
    final pool = _pools[base] ?? const <Question>[];
    if (pool.isEmpty || count <= 0) return [];

    final taken = <String>{...exclude};
    final picked = <Question>[];
    final usedCategories = <String>[];
    // Antigüedad: posición en el historial (menor = visto hace más tiempo).
    final age = {for (var i = 0; i < _seen.length; i++) _seen[i]: i};
    final levels = [
      for (var d = base; d <= min(base + _harderSteps, maxDifficulty); d++) d,
    ];

    // Rondas 1 y 2: nunca vistas (dificultad del nivel y luego más
    // difíciles); después, vistas una vez (las más antiguas primero).
    for (var times = 0; times < maxShows && picked.length < count; times++) {
      for (final d in levels) {
        if (picked.length >= count) break;
        final candidates = [
          for (final q in _pools[d] ?? const <Question>[])
            if (!taken.contains(q.id) && timesShown(q.id) == times) q,
        ];
        _pickInto(
          candidates,
          count: count,
          picked: picked,
          taken: taken,
          usedCategories: usedCategories,
          preferCategory: preferCategory,
          age: times == 0 ? null : age,
        );
      }
    }

    // Último recurso: todo el banco cercano ya salió 2 veces. Se usan las
    // de la dificultad del nivel que hace más tiempo que no salen.
    if (picked.length < count) {
      final rest = [for (final q in pool) if (!taken.contains(q.id)) q]
        ..sort((a, b) => (age[a.id] ?? -1).compareTo(age[b.id] ?? -1));
      for (final q in rest) {
        if (picked.length >= count) break;
        picked.add(q);
        taken.add(q.id);
      }
    }

    _remember(picked);
    return picked.map(_shuffled).toList();
  }

  /// Añade a [picked] preguntas de [candidates], variando la categoría.
  /// Con [age], dentro de cada categoría elige la vista hace más tiempo; sin
  /// ella (preguntas nuevas), una al azar.
  static void _pickInto(
    List<Question> candidates, {
    required int count,
    required List<Question> picked,
    required Set<String> taken,
    required List<String> usedCategories,
    String? preferCategory,
    Map<String, int>? age,
  }) {
    while (picked.length < count && candidates.isNotEmpty) {
      final category = picked.isEmpty &&
              preferCategory != null &&
              candidates.any((q) => q.category == preferCategory)
          ? preferCategory
          : _leastRecentCategory(candidates, usedCategories);
      final options = candidates.where((q) => q.category == category).toList();
      final Question question;
      if (age == null) {
        question = options[_random.nextInt(options.length)];
      } else {
        options.sort((a, b) => (age[a.id] ?? -1).compareTo(age[b.id] ?? -1));
        question = options.first;
      }
      candidates.remove(question);
      picked.add(question);
      taken.add(question.id);
      usedCategories.add(category);
    }
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
      _shown[question.id] = timesShown(question.id) + 1;
      _recentCategories.add(question.category);
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
          '$_shownKeyPrefix$_language', [for (final e in _shown.entries) '${e.key}=${e.value}']);
      await prefs.setStringList(
          '$_recentCategoriesKeyPrefix$_language', List.of(_recentCategories));
    } catch (error) {
      debugPrint('No se pudo guardar el historial de preguntas: $error');
    }
  }

  /// Preguntas IGUALES para todos los jugadores (torneo semanal).
  ///
  /// Con la misma [seed] (semilla) salen las mismas preguntas en el mismo
  /// orden y con las opciones en el mismo orden, en cualquier teléfono. No
  /// tocan el historial de preguntas vistas del modo aventura.
  static List<Question> seeded({
    required int difficulty,
    required int count,
    required int seed,
  }) {
    final pool = List<Question>.of(
      _pools[difficulty.clamp(minDifficulty, maxDifficulty)] ?? const [],
    )..sort((a, b) => a.id.compareTo(b.id));
    if (pool.isEmpty || count <= 0) return [];
    final random = Random(seed);
    pool.shuffle(random);
    return [for (final q in pool.take(count)) _shuffled(q, random)];
  }

  /// Baraja las opciones y recalcula cuál es la correcta.
  static Question _shuffled(Question question, [Random? random]) {
    final correct = question.options[question.correctIndex];
    final options = List<String>.of(question.options)..shuffle(random ?? _random);
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
