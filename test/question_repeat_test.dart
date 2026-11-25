// Regla de repetición del banco de preguntas: ninguna pregunta sale más de
// 2 veces mientras queden otras, y antes de repetir se usan preguntas
// nuevas de dificultades más altas.
//
// Ejecutar con:  flutter test test/question_repeat_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:words_and_monsters/models/question.dart';
import 'package:words_and_monsters/services/question_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await QuestionRepository.load(language: 'es');
  });

  int maxShown(Iterable<Question> qs) =>
      qs.map((q) => QuestionRepository.timesShown(q.id)).fold(0, (a, b) => a > b ? a : b);

  test('primero salen preguntas de la dificultad del nivel', () {
    final first = QuestionRepository.draw(difficulty: 2, count: 6);
    expect(first.length, 6);
    expect(first.every((q) => q.difficulty == 2), isTrue);
  });

  test('ninguna se repite hasta agotar su dificultad y las 2 siguientes', () {
    final unique = QuestionRepository.countFor(2) +
        QuestionRepository.countFor(3) +
        QuestionRepository.countFor(4);
    final all = <Question>[];
    for (var i = 0; i < unique ~/ 6; i++) {
      all.addAll(QuestionRepository.draw(difficulty: 2, count: 6));
    }
    expect(maxShown(all), 1, reason: 'Ninguna debería haber salido 2 veces todavía');
    expect(all.any((q) => q.difficulty > 2), isTrue,
        reason: 'Al acabarse las de dificultad 2 deben salir más difíciles');
  });

  test('ninguna sale más de 2 veces mientras queden otras', () {
    final unique = QuestionRepository.countFor(2) +
        QuestionRepository.countFor(3) +
        QuestionRepository.countFor(4);
    final all = <Question>[];
    for (var i = 0; i < (unique * 2) ~/ 6; i++) {
      all.addAll(QuestionRepository.draw(difficulty: 2, count: 6));
    }
    expect(maxShown(all), lessThanOrEqualTo(2));
  });

  test('las vistas se recuerdan al volver a abrir el juego', () async {
    final picked = QuestionRepository.draw(difficulty: 3, count: 4);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // guardado
    await QuestionRepository.load(language: 'es');
    for (final q in picked) {
      expect(QuestionRepository.timesShown(q.id), 1);
    }
  });
}
