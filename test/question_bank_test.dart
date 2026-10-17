// Validador del banco de preguntas.
//
// Ejecutar con:  flutter test test/question_bank_test.dart
//
// Comprueba el FORMATO de todas las preguntas de todos los idiomas.
// Lo que no puede comprobar es si la respuesta es cierta: eso lo revisa
// una persona con las preguntas de muestra de cada tanda.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:words_and_monsters/services/question_repository.dart';

/// Mínimo de preguntas por dificultad para lanzar (una partida completa
/// sin repetir) y meta final (para rejugar sin repetir).
const minimumForLaunch = {1: 70, 2: 150, 3: 150, 4: 150, 5: 80};
const finalTarget = {1: 120, 2: 250, 3: 250, 4: 250, 5: 150};

/// Reparto previsto de temas.
const groups = {
  'Lengua': ['ortografia', 'tildes', 'homofonos', 'detectar_error',
      'completar_frase', 'sinonimos_antonimos', 'significado', 'refranes'],
  'Lógica con palabras': ['analogias', 'intruso', 'series', 'anagramas',
      'palabra_oculta', 'silabas', 'adivinanzas', 'deduccion', 'problemas'],
  'Apoyo': ['ciencia', 'geografia', 'historia', 'cultura_general'],
};
const expectedShare = {'Lengua': 45, 'Lógica con palabras': 35, 'Apoyo': 20};

const validTypes = ['multipleChoice', 'errorDetection', 'fillInBlank', 'homophones'];
const requiredFields = ['id', 'category', 'type', 'prompt', 'options', 'correctIndex', 'explanation'];

const maxPromptLength = 140;
const maxOptionLength = 40;
const maxExplanationLength = 160;

String normalize(String text) => text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  for (final language in QuestionRepository.availableLanguages) {
    group('Banco de preguntas [$language]', () {
      final allIds = <String>{};
      final allPrompts = <String, String>{};

      for (var difficulty = 1; difficulty <= 5; difficulty++) {
        final path = 'assets/questions/$language/dificultad_$difficulty.json';

        test('dificultad $difficulty', () {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: 'Falta el archivo $path');

          final Map<String, dynamic> data;
          try {
            data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          } catch (error) {
            fail('$path no es un JSON válido: $error');
          }

          expect(data['language'], language, reason: '$path: "language" no coincide');
          expect(data['difficulty'], difficulty, reason: '$path: "difficulty" no coincide');

          final questions = data['questions'] as List;
          final errors = <String>[];
          final perCategory = <String, int>{};

          for (final raw in questions) {
            final q = raw as Map<String, dynamic>;
            final id = q['id']?.toString() ?? '(sin id)';
            void error(String message) => errors.add('$id: $message');

            final missing = requiredFields.where((f) => !q.containsKey(f)).toList();
            if (missing.isNotEmpty) {
              error('faltan los campos ${missing.join(', ')}');
              continue;
            }

            if (!allIds.add(id)) error('ID repetido');
            if (!id.startsWith('$language-$difficulty-')) {
              error('el ID debe empezar por "$language-$difficulty-"');
            }

            final category = q['category'] as String;
            if (!QuestionRepository.categoryNames.containsKey(category)) {
              error('categoría desconocida "$category"');
            }
            perCategory[category] = (perCategory[category] ?? 0) + 1;

            if (!validTypes.contains(q['type'])) error('tipo desconocido "${q['type']}"');

            final prompt = q['prompt'] as String;
            if (prompt.trim().isEmpty) error('enunciado vacío');
            if (prompt.length > maxPromptLength) {
              error('enunciado de ${prompt.length} caracteres (máximo $maxPromptLength)');
            }
            final previous = allPrompts[normalize(prompt)];
            if (previous != null) error('mismo enunciado que $previous');
            allPrompts[normalize(prompt)] = id;

            final options = List<String>.from(q['options'] as List);
            if (options.length != 4) error('debe tener 4 opciones (tiene ${options.length})');
            if (options.map(normalize).toSet().length != options.length) {
              error('hay opciones repetidas');
            }
            for (final option in options) {
              if (option.trim().isEmpty) error('opción vacía');
              if (option.length > maxOptionLength) {
                error('opción "$option" de ${option.length} caracteres (máximo $maxOptionLength)');
              }
            }

            if (q['correctIndex'] != 0) {
              error('la respuesta correcta debe ir la primera (correctIndex = 0)');
            }

            final explanation = q['explanation'] as String;
            if (explanation.trim().isEmpty) error('explicación vacía');
            if (explanation.length > maxExplanationLength) {
              error('explicación de ${explanation.length} caracteres (máximo $maxExplanationLength)');
            }
            // Las opciones se barajan en el juego: la explicación no puede
            // referirse a su posición.
            if (RegExp(r'opci[oó]n\s+[ABCD]\b|primera opci[oó]n|segunda opci[oó]n',
                    caseSensitive: false)
                .hasMatch(explanation)) {
              error('la explicación menciona la posición de una opción');
            }
          }

          // Avisos (no hacen fallar el test): cantidad y reparto de temas.
          final count = questions.length;
          final status = count >= finalTarget[difficulty]!
              ? 'meta final alcanzada'
              : count >= minimumForLaunch[difficulty]!
                  ? 'listo para lanzar (meta final: ${finalTarget[difficulty]})'
                  : 'AVISO: faltan ${minimumForLaunch[difficulty]! - count} para el mínimo de lanzamiento';
          final shares = groups.map((name, ids) {
            final inGroup = ids.fold<int>(0, (sum, c) => sum + (perCategory[c] ?? 0));
            return MapEntry(name, count == 0 ? 0 : (inGroup * 100 / count).round());
          });
          // ignore: avoid_print
          print('[$language] dificultad $difficulty: $count preguntas · $status · '
              '${shares.entries.map((e) => '${e.key} ${e.value} % (previsto ${expectedShare[e.key]} %)').join(', ')}');

          expect(errors, isEmpty, reason: '\n${errors.join('\n')}');
        });
      }
    });
  }
}
