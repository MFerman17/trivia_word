import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vidas globales del jugador, como en Candy Crush.
///
/// - Hay un máximo de [maxLives] para todo el juego (no por nivel).
/// - Cada fallo en un combate gasta una vida, y se queda gastada al
///   pasar al siguiente nivel.
/// - Se recupera 1 vida cada [refillTime]. También al instante con una
///   poción, viendo un video, con gemas o al subir de nivel.
/// - Con 0 vidas no se puede empezar un nivel ni una pelea.
///
/// Por qué así: si las vidas se rellenaran en cada nivel, las pociones,
/// las pistas y los videos casi no servirían. Así cada error importa y
/// esas ayudas tienen valor.
///
/// Se guarda solo en el teléfono (no en la nube): son algo pasajero que se
/// recarga solo, y así no hay que cambiar las reglas de Firestore.
class LivesService {
  LivesService._();

  static const int maxLives = 5;
  static const Duration refillTime = Duration(minutes: 20);

  /// Gemas para rellenar todas las vidas de golpe.
  static const int gemsForFullRefill = 5;

  static const String _livesKey = 'lives_count';
  static const String _refillStartKey = 'lives_refill_start';

  /// Vidas actuales. Las pantallas lo escuchan para redibujar los corazones.
  static final ValueNotifier<int> lives = ValueNotifier(maxLives);

  /// Momento desde el que cuenta la recarga de la siguiente vida
  /// (null si las vidas están llenas).
  static DateTime? _refillStart;

  static bool get isFull => lives.value >= maxLives;
  static bool get hasLives => lives.value > 0;

  /// Lee las vidas guardadas y suma las que se recargaron con la app cerrada.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lives.value = (prefs.getInt(_livesKey) ?? maxLives).clamp(0, maxLives).toInt();
      final start = prefs.getString(_refillStartKey);
      _refillStart = start == null ? null : DateTime.tryParse(start);
    } catch (e) {
      debugPrint('❤️ No se pudieron leer las vidas: $e');
    }
    refresh();
  }

  /// Suma las vidas que ya se recargaron. Se llama cada segundo desde el
  /// contador de vidas y antes de empezar un nivel.
  static void refresh() {
    final start = _refillStart;
    if (isFull) {
      _refillStart = null;
      return;
    }
    if (start == null) {
      _refillStart = DateTime.now();
      _save();
      return;
    }
    final elapsed = DateTime.now().difference(start);
    final gained = elapsed.inSeconds ~/ refillTime.inSeconds;
    if (gained <= 0) return;
    final newLives = (lives.value + gained).clamp(0, maxLives).toInt();
    // Si no se llenan, el tiempo "sobrante" cuenta para la siguiente vida.
    _refillStart = newLives >= maxLives ? null : start.add(refillTime * gained);
    lives.value = newLives;
    _save();
  }

  /// Tiempo que falta para la siguiente vida (null si están llenas).
  static Duration? get timeToNextLife {
    refresh();
    final start = _refillStart;
    if (isFull || start == null) return null;
    final left = start.add(refillTime).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Igual que [timeToNextLife] pero sin sumar vidas: se puede usar
  /// mientras se dibuja una pantalla (no avisa a nadie).
  static Duration? get timeToNextLifeCached {
    final start = _refillStart;
    if (isFull || start == null) return null;
    final left = start.add(refillTime).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Gasta una vida (un fallo en combate o perder una pelea).
  static void loseLife() {
    refresh();
    if (lives.value <= 0) return;
    // Si estaban llenas, la recarga empieza a contar ahora.
    if (isFull) _refillStart = DateTime.now();
    lives.value--;
    _save();
  }

  /// Suma vidas (poción, video, subir de nivel). Nunca pasa del máximo.
  static void addLives(int amount) {
    refresh();
    lives.value = (lives.value + amount).clamp(0, maxLives).toInt();
    if (isFull) _refillStart = null;
    _save();
  }

  /// Rellena todas las vidas.
  static void refillAll() => addLives(maxLives);

  /// Fija las vidas a un número (al revivir en combate con 1 vida).
  static void setLives(int value) {
    refresh();
    final wasFull = isFull;
    lives.value = value.clamp(0, maxLives).toInt();
    if (isFull) {
      _refillStart = null;
    } else if (wasFull || _refillStart == null) {
      _refillStart = DateTime.now();
    }
    _save();
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_livesKey, lives.value);
      final start = _refillStart;
      if (start == null) {
        await prefs.remove(_refillStartKey);
      } else {
        await prefs.setString(_refillStartKey, start.toIso8601String());
      }
    } catch (e) {
      debugPrint('❤️ No se pudieron guardar las vidas: $e');
    }
  }
}
