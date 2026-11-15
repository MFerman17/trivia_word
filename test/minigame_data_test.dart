// Comprueba los datos de los minijuegos de palabras (assets/minigames).
//
// Ejecutar con:  flutter test test/minigame_data_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:words_and_monsters/services/minigame_service.dart';

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('assets/minigames/$name.json').readAsStringSync()) as Map<String, dynamic>;

final _upper = RegExp(r'^[A-ZÁÉÍÓÚÜÑ]+$');

void main() {
  for (final lang in ['es', 'en']) {
    group('Datos en $lang', () {
      test('Letras revueltas: palabras de 5 a 8 letras sin tildes, con pista', () {
        final words = (_read('scramble_$lang')['words'] as List).cast<Map<String, dynamic>>();
        expect(words.length, greaterThanOrEqualTo(30));
        final seen = <String>{};
        for (final w in words) {
          final word = w['word'] as String;
          expect(RegExp(r'^[A-Z]{5,8}$').hasMatch(word), isTrue, reason: word);
          expect((w['hint'] as String).trim(), isNotEmpty, reason: word);
          expect((w['hint'] as String).toUpperCase().contains(word), isFalse,
              reason: 'La pista de $word no debe contener la palabra');
          expect(seen.add(word), isTrue, reason: 'Repetida: $word');
        }
      });

      test('¿Bien escrita?: cada pareja tiene dos formas distintas', () {
        final items = (_read('spelling_$lang')['items'] as List).cast<Map<String, dynamic>>();
        expect(items.length, greaterThanOrEqualTo(30));
        for (final i in items) {
          final right = i['right'] as String;
          final wrong = i['wrong'] as String;
          expect(_upper.hasMatch(right), isTrue, reason: right);
          expect(_upper.hasMatch(wrong), isTrue, reason: wrong);
          expect(right, isNot(wrong));
        }
      });

      test('Serpiente: palabras cortas (3 a 5) sin tildes ni Ñ', () {
        final words = List<String>.from(_read('snake_$lang')['words'] as List);
        expect(words.length, greaterThanOrEqualTo(20));
        for (final w in words) {
          expect(RegExp(r'^[A-Z]{3,5}$').hasMatch(w), isTrue, reason: w);
        }
      });
    });
  }

  test('Todos los minijuegos aparecen en los portales del mapa', () {
    final seen = <MinigameType>{};
    for (var w = 1; w <= 6; w++) {
      for (var c = 1; c <= 3; c++) {
        for (final l in MinigameService.portalLevels) {
          seen.add(MinigameService.typeFor(w, c, l));
        }
      }
    }
    expect(seen, MinigameType.values.toSet());
  });
}
