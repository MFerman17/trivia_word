// Comprueba que todos los idiomas tienen los mismos textos que el español.
//
// Ejecutar con:  flutter test test/l10n_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Nombres de los huecos de un texto, por ejemplo {level} -> level.
Set<String> placeholders(String text) =>
    RegExp(r'\{(\w+)[,}]').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final base = readArb('lib/l10n/app_es.arb');
  final keys = base.keys.where((k) => !k.startsWith('@')).toSet();

  final others = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb') && !f.path.endsWith('app_es.arb'));

  for (final file in others) {
    test('textos de ${file.uri.pathSegments.last}', () {
      final arb = readArb(file.path);
      final errors = <String>[];
      for (final key in keys) {
        final value = arb[key];
        if (value is! String || value.trim().isEmpty) {
          errors.add('falta "$key"');
        } else if (!setEquals(placeholders(value), placeholders(base[key] as String))) {
          errors.add('"$key" no tiene los mismos huecos que en español');
        }
      }
      for (final key in arb.keys.where((k) => !k.startsWith('@'))) {
        if (!keys.contains(key)) errors.add('"$key" no existe en español');
      }
      expect(errors, isEmpty, reason: '\n${errors.join('\n')}');
    });
  }
}

bool setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
