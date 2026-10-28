import 'dart:math' as math;

import '../l10n/l10n.dart';

/// Frases que aparecen al responder: felicitaciones al acertar y ánimo al
/// fallar. Van cambiando y nunca repiten la última que salió de su tipo,
/// para que se sientan vivas y no un mensaje fijo.
class CheerService {
  CheerService._();

  static final math.Random _random = math.Random();
  static int _lastPraise = -1;
  static int _lastEncourage = -1;

  static List<String> _praises(AppLocalizations l) => [
        l.praise1, l.praise2, l.praise3, l.praise4, l.praise5, l.praise6,
        l.praise7, l.praise8, l.praise9, l.praise10, l.praise11, l.praise12,
      ];

  static List<String> _encouragements(AppLocalizations l) => [
        l.encourage1, l.encourage2, l.encourage3, l.encourage4, l.encourage5,
        l.encourage6, l.encourage7, l.encourage8, l.encourage9, l.encourage10,
      ];

  /// Una frase nueva: de felicitación si [correct], de ánimo si no.
  static String next({required bool correct}) {
    final list = correct ? _praises(L10n.current) : _encouragements(L10n.current);
    final last = correct ? _lastPraise : _lastEncourage;
    var index = _random.nextInt(list.length);
    if (index == last) index = (index + 1) % list.length;
    if (correct) {
      _lastPraise = index;
    } else {
      _lastEncourage = index;
    }
    return list[index];
  }
}
