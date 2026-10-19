import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'question_repository.dart';

/// Decide en qué idioma se ve el juego y lo recuerda.
///
/// Un idioma solo se ofrece si tiene las DOS cosas:
///  - los textos de la app (lib/l10n/app_xx.arb), y
///  - su propio banco de preguntas (assets/questions/xx/).
/// En un juego de palabras no sirve traducir solo los botones: las preguntas
/// de ortografía o refranes tienen que estar escritas para ese idioma.
///
/// La primera vez se usa el idioma del teléfono si está disponible; si no,
/// inglés (cuando exista) y, por último, español.
class LocaleService {
  LocaleService._();

  static const String _key = 'app_language';
  static const String _defaultLanguage = 'es';

  /// Idioma actual. MaterialApp lo escucha y se redibuja al cambiarlo.
  static final ValueNotifier<Locale> locale =
      ValueNotifier(const Locale(_defaultLanguage));

  static String get languageCode => locale.value.languageCode;

  /// Idiomas que el jugador puede elegir.
  static List<String> get availableLanguages => [
        for (final l in AppLocalizations.supportedLocales)
          if (QuestionRepository.availableLanguages.contains(l.languageCode))
            l.languageCode,
      ];

  static List<Locale> get supportedLocales =>
      [for (final code in availableLanguages) Locale(code)];

  /// Nombre de cada idioma escrito en ese mismo idioma, para el selector.
  static const Map<String, String> nativeNames = {
    'es': 'Español',
    'en': 'English',
    'pt': 'Português',
    'fr': 'Français',
    'it': 'Italiano',
    'de': 'Deutsch',
  };

  /// Lee el idioma guardado (o el del teléfono). Se llama al arrancar,
  /// antes de cargar el banco de preguntas.
  static Future<void> init() async {
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(_key);
    } catch (e) {
      debugPrint('🌐 No se pudo leer el idioma guardado: $e');
    }
    locale.value = Locale(_resolve(saved));
  }

  static String _resolve(String? saved) {
    final available = availableLanguages;
    if (saved != null && available.contains(saved)) return saved;
    for (final device in WidgetsBinding.instance.platformDispatcher.locales) {
      if (available.contains(device.languageCode)) return device.languageCode;
    }
    if (available.contains('en')) return 'en';
    return available.isNotEmpty ? available.first : _defaultLanguage;
  }

  /// Cambia el idioma: lo guarda, recarga las preguntas y redibuja la app.
  static Future<void> setLanguage(String code) async {
    if (!availableLanguages.contains(code) || code == languageCode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (e) {
      debugPrint('🌐 No se pudo guardar el idioma: $e');
    }
    await QuestionRepository.load(language: code);
    locale.value = Locale(code);
  }
}
