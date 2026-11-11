import 'package:shared_preferences/shared_preferences.dart';

/// PANTALLA DE EDAD NEUTRAL
///
/// Words & Monsters tiene monstruos y colores que pueden gustar a niños,
/// así que Google Play lo trata como app de "público mixto". Para mostrar
/// anuncios normales hay que preguntar la edad de forma NEUTRAL: sin decir
/// qué respuesta "desbloquea" algo y sin proponer un año de adulto.
///
/// Si el jugador es menor de 13 años:
///   - Los anuncios se piden como "dirigidos a niños" (sin personalizar y
///     solo de contenido apto para todos). AdMob se encarga de usar solo
///     redes certificadas para familias.
///   - No se envía analítica.
///
/// Solo se guarda en el teléfono si es menor o no (no el año exacto).
class AgeGateService {
  AgeGateService._();

  static const _key = 'age_band'; // 'child' o 'general'

  static String? _band;

  /// Si ya respondió (la pantalla sale una sola vez).
  static bool get answered => _band != null;

  /// true si es (o podría ser) menor de 13 años.
  static bool get isChild => _band == 'child';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _band = prefs.getString(_key);
    } catch (_) {}
  }

  /// Guarda la respuesta a partir del año de nacimiento.
  ///
  /// Solo con el año no se sabe si ya cumplió años, así que alguien que
  /// cumple 13 este año se trata como niño (lo más prudente).
  static Future<void> setBirthYear(int year) async {
    final age = DateTime.now().year - year;
    _band = age <= 13 ? 'child' : 'general';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _band!);
    } catch (_) {}
  }
}
