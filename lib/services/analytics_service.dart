import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'age_gate_service.dart';

/// ANALÍTICA (Firebase Analytics)
///
/// Firebase ya mide solo lo básico: instalaciones, sesiones, países y la
/// RETENCIÓN (cuántos vuelven el día 1, 7, 30), sin escribir código. Lo que
/// se añade aquí son los momentos propios del juego, para responder
/// preguntas como:
///   - ¿En qué nivel abandona la gente? (level_start sin level_end)
///   - ¿Qué nivel es demasiado difícil? (level_end con success = 0)
///   - ¿Cuántos videos se ven y en qué sitio? (ad_reward)
///   - ¿Cuántos terminan cada mundo? (world_complete)
///
/// Nada de esto identifica al jugador: no se envían nombres ni correos.
/// Si Firebase no arrancó (sin internet la primera vez, en pruebas), las
/// llamadas no hacen nada y el juego sigue igual.
class AnalyticsService {
  AnalyticsService._();

  static FirebaseAnalytics? get _fa {
    try {
      // A los menores de 13 no se les mide nada.
      if (Firebase.apps.isEmpty || AgeGateService.isChild) return null;
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analítica: no se pudo enviar $name: $e');
    }
  }

  /// Firebase mide sesiones y retención por su cuenta; para menores de 13
  /// se apaga del todo. Se llama al saber la edad.
  static Future<void> applyAge() async {
    try {
      if (Firebase.apps.isEmpty) return;
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(!AgeGateService.isChild);
    } catch (e) {
      debugPrint('Analítica: no se pudo aplicar la edad: $e');
    }
  }

  /// Nivel con formato "1-2-3" (mundo-capítulo-nivel) para verlos juntos.
  static String _id(int world, int chapter, int level) => '$world-$chapter-$level';

  static void levelStart({required int world, required int chapter, required int level}) =>
      _log('level_start', {'level_name': _id(world, chapter, level), 'world': world});

  static void levelEnd({
    required int world,
    required int chapter,
    required int level,
    required bool success,
    int stars = 0,
    bool fight = false,
  }) =>
      _log('level_end', {
        'level_name': _id(world, chapter, level),
        'world': world,
        // Firebase no guarda booleanos: 1 = ganado, 0 = perdido.
        'success': success ? 1 : 0,
        'stars': stars,
        'fight': fight ? 1 : 0,
      });

  static void worldComplete(int world) => _log('world_complete', {'world': world});

  static void tutorialComplete() => _log('tutorial_complete');

  /// Video visto hasta el final (o premio VIP sin video) y en qué sitio.
  static void adReward(String placement, {bool vip = false}) =>
      _log('ad_reward', {'placement': placement, 'vip': vip ? 1 : 0});

  static void dailyChallenge(int score, int correct) =>
      _log('daily_challenge', {'score': score, 'correct': correct});

  static void towerRun(int floors) => _log('tower_run', {'floors': floors});

  static void streakClaim(int day) => _log('streak_claim', {'day': day});

  static void vipPurchased(ProductDetails? product) => _log('vip_purchase', {
        if (product != null) 'value': product.rawPrice,
        if (product != null) 'currency': product.currencyCode,
      });
}
