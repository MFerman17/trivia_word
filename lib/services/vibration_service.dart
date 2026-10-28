import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vibración del teléfono en los golpes del combate y de las peleas.
///
/// En Android usa el motor de vibración real (canal nativo en
/// MainActivity.kt). En el resto, o si falla, el "toque" estándar de Flutter.
/// El jugador puede desactivarla en Ajustes.
class VibrationService {
  VibrationService._();

  static const MethodChannel _channel = MethodChannel('wordsandmonsters/vibration');
  static const String _key = 'vibration_on';

  static bool enabled = true;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_key) ?? true;
    } catch (_) {}
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    if (value) hit();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }

  /// Golpe: corto y suave cuando pegas tú; largo y fuerte cuando te pegan.
  static Future<void> hit({bool strong = false}) async {
    if (!enabled || kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('vibrate', {
          'ms': strong ? 140 : 55,
          'amplitude': strong ? 255 : 170,
        });
        return;
      } catch (_) {
        // Si el canal no responde, se usa el toque estándar.
      }
    }
    strong ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
  }
}
