import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';
import '../models/question.dart';
import 'cloud_service.dart';
import 'analytics_service.dart';
import 'question_repository.dart';
import 'save_service.dart';

/// TORRE INFINITA
///
/// Un modo sin final: cada pregunta acertada es un piso más. Se empieza con
/// 3 vidas y cada fallo (o tiempo agotado) quita una; sin vidas, se acaba la
/// subida. Cuanto más alto, más difícil: los primeros pisos son fáciles para
/// que cualquiera llegue lejos, y desde el piso 36 todo es dificultad 5.
///
/// El récord (piso más alto alcanzado) va a una clasificación de la torre.
/// Se puede subir una vez al día gratis y dos más viendo un video.
///
/// Estructura en Firestore:   tower/{uid}  (récord de cada jugador)
class TowerService {
  TowerService._();

  static const int lives = 3;
  static const int secondsPerQuestion = 20;
  static const int freeRunsPerDay = 1;
  static const int videoRunsPerDay = 2;
  static const int rankingSize = 50;

  /// Las reglas no dejan guardar récords más altos que este (un tope
  /// imposible de alcanzar jugando de verdad, para frenar trampas).
  static const int maxFloor = 1000;

  /// Premio: monedas por piso y una gema cada 25 pisos.
  static const int coinsPerFloor = 5;
  static const int floorsPerGem = 25;

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Dificultad del piso [floor] (1, 2, 3...).
  static int difficultyFor(int floor) => floor <= 5
      ? 1
      : floor <= 10
          ? 2
          : floor <= 20
              ? 3
              : floor <= 35
                  ? 4
                  : 5;

  /// Pregunta del piso [floor], sin repetir las de esta subida.
  static Question? questionFor(int floor, Set<String> used) {
    final picked = QuestionRepository.draw(difficulty: difficultyFor(floor), count: 1, exclude: used);
    if (picked.isEmpty) return null;
    used.add(picked.first.id);
    return picked.first;
  }

  static int coinsFor(int floors) => floors * coinsPerFloor;
  static int gemsFor(int floors) => floors ~/ floorsPerGem;

  // ------------------------------------------------------------------
  // SUBIDAS DEL DÍA (en el teléfono)
  // ------------------------------------------------------------------

  static String _dayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static Future<({int used, int videos})> runsToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        used: prefs.getInt('tower_runs_${_dayKey()}') ?? 0,
        videos: prefs.getInt('tower_videos_${_dayKey()}') ?? 0,
      );
    } catch (_) {
      return (used: 0, videos: 0);
    }
  }

  /// Subidas que quedan hoy.
  static Future<int> runsLeft() async {
    final r = await runsToday();
    return (freeRunsPerDay + r.videos - r.used).clamp(0, 99);
  }

  static Future<void> useRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tower_runs_${_dayKey()}';
      await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    } catch (_) {}
  }

  static Future<void> addVideoRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tower_videos_${_dayKey()}';
      final now = prefs.getInt(key) ?? 0;
      if (now < videoRunsPerDay) await prefs.setInt(key, now + 1);
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // RÉCORD
  // ------------------------------------------------------------------

  /// Récord guardado en el teléfono (se ve aunque no haya conexión).
  static Future<int> localBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('tower_best') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<User?> _user() => CloudService.signInAnonymously();

  static String _name(PlayerProfile profile, String uid) {
    final name = profile.name.trim().isEmpty ? 'Jugador_${uid.substring(0, 5)}' : profile.name.trim();
    return String.fromCharCodes(name.runes.take(20));
  }

  /// Cierra una subida: da el premio y, si es récord, lo guarda (en el
  /// teléfono y en la clasificación). Devuelve si fue un récord nuevo.
  static Future<bool> finishRun(int floors) async {
    AnalyticsService.towerRun(floors);
    final profile = await SaveService.loadPlayerData();
    profile.coins += coinsFor(floors);
    profile.gems += gemsFor(floors);
    await SaveService.savePlayerData(profile);

    final best = await localBest();
    final record = floors > best;
    if (record) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('tower_best', floors);
      } catch (_) {}
    }
    // Se sube el mejor de los dos (por si el de la nube se quedó atrás).
    final top = record ? floors : best;
    if (top > 0) {
      try {
        final user = await _user();
        if (user != null) {
          final ref = _db.collection('tower').doc(user.uid);
          final doc = await ref.get();
          final cloud = (doc.data()?['bestFloor'] as num?)?.toInt() ?? 0;
          if (top > cloud) {
            await ref.set({
              'name': _name(profile, user.uid),
              if (profile.country.length == 2) 'country': profile.country,
              'bestFloor': top.clamp(0, maxFloor),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        debugPrint('Torre: no se pudo guardar el récord: $e');
      }
    }
    return record;
  }

  static Future<List<Map<String, dynamic>>> ranking() async {
    try {
      await _user();
      final snapshot = await _db
          .collection('tower')
          .orderBy('bestFloor', descending: true)
          .limit(rankingSize)
          .get();
      return [for (final doc in snapshot.docs) {...doc.data(), 'uid': doc.id}];
    } catch (e) {
      debugPrint('Torre: no se pudo cargar la clasificación: $e');
      return [];
    }
  }

  static Future<int?> rankOf(int floor) async {
    if (floor <= 0) return null;
    try {
      final result = await _db.collection('tower').where('bestFloor', isGreaterThan: floor).count().get();
      return (result.count ?? 0) + 1;
    } catch (e) {
      debugPrint('Torre: no se pudo calcular el puesto: $e');
      return null;
    }
  }

  static Future<void> deleteMyEntry(String uid) => _db.collection('tower').doc(uid).delete();
}
