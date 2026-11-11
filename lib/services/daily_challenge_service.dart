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
import 'tournament_service.dart';

/// Resultado del reto de hoy (o de un día concreto).
class DailyEntry {
  const DailyEntry({required this.score, required this.correct, required this.finished});
  final int score;
  final int correct;
  final bool finished;
}

/// RETO DIARIO
///
/// Cada día (de 00:00 a 24:00 UTC, igual para todo el mundo) hay 5
/// preguntas, LAS MISMAS para todos los jugadores, de menos a más difícil
/// (una de cada dificultad). Se juega UNA vez al día y los puntos van a una
/// clasificación de ese día: así cada mañana hay una carrera nueva y todos
/// parten de cero, lleven el tiempo que lleven jugando.
///
/// Los puntos se calculan igual que en el torneo (acierto + rapidez + racha).
/// Funciona con el plan gratis de Firebase, igual que el torneo: el intento
/// se apunta en la nube AL EMPEZAR (salir a mitad cuenta como jugado) y las
/// reglas comprueban que la puntuación sea posible y el tiempo razonable.
///
/// Estructura en Firestore:   daily/{día}/entries/{uid}
class DailyChallengeService {
  DailyChallengeService._();

  static const int questionCount = 5;
  static const int secondsPerQuestion = TournamentService.secondsPerQuestion;
  static const int maxScore =
      questionCount * (TournamentService.basePoints + secondsPerQuestion * TournamentService.pointsPerSecond + TournamentService.maxStreakBonus);
  static const int rankingSize = 50;

  /// Premio por jugar: base + por acierto; con las 5 bien, una gema.
  static const int baseCoins = 20;
  static const int coinsPerCorrect = 10;

  /// Las reglas exigen al menos 10 s entre empezar y entregar.
  static const Duration minRunTime = Duration(seconds: 12);
  static DateTime? _runStartedAt;

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ------------------------------------------------------------------
  // DÍA
  // ------------------------------------------------------------------

  /// Hoy a las 00:00 UTC.
  static DateTime dayStart([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  static String dayId(DateTime start) => start.millisecondsSinceEpoch.toString();

  static Duration timeLeft() =>
      dayStart().add(const Duration(days: 1)).difference(DateTime.now().toUtc());

  /// Las 5 preguntas de hoy, de la dificultad 1 a la 5.
  static List<Question> questionsToday() {
    final days = dayStart().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return [
      for (var d = 1; d <= questionCount; d++)
        ...QuestionRepository.seeded(difficulty: d, count: 1, seed: days * 10 + d),
    ];
  }

  static int coinsFor(int correct) => baseCoins + correct * coinsPerCorrect;
  static int gemsFor(int correct) => correct >= questionCount ? 1 : 0;

  // ------------------------------------------------------------------
  // EN EL TELÉFONO: ya jugado hoy / premio cobrado
  // ------------------------------------------------------------------

  static String _playedKey(DateTime start) => 'daily_played_${dayId(start)}';

  static Future<bool> playedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_playedKey(dayStart())) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_playedKey(dayStart()), true);
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // NUBE
  // ------------------------------------------------------------------

  static Future<User?> _user() => CloudService.signInAnonymously();

  static DocumentReference<Map<String, dynamic>> _ref(DateTime start, String uid) =>
      _db.collection('daily').doc(dayId(start)).collection('entries').doc(uid);

  static String _name(PlayerProfile profile, String uid) {
    final name = profile.name.trim().isEmpty ? 'Jugador_${uid.substring(0, 5)}' : profile.name.trim();
    return String.fromCharCodes(name.runes.take(20));
  }

  /// Mi resultado de hoy (null si no he jugado o no hay conexión).
  static Future<DailyEntry?> myEntry() async {
    try {
      final user = await _user();
      if (user == null) return null;
      final doc = await _ref(dayStart(), user.uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return DailyEntry(
        score: (data['score'] as num?)?.toInt() ?? 0,
        correct: (data['correct'] as num?)?.toInt() ?? 0,
        finished: data['finished'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('Reto diario: no se pudo leer mi resultado: $e');
      return null;
    }
  }

  /// Apunta el intento en la nube ANTES de jugar. Devuelve false si ya se
  /// jugó hoy o no hay conexión (sin conexión no se puede competir).
  static Future<bool> start(PlayerProfile profile) async {
    if (await playedToday()) return false;
    final start = dayStart();
    try {
      final user = await _user();
      if (user == null) return false;
      final ref = _ref(start, user.uid);
      if ((await ref.get()).exists) {
        await _markPlayed();
        return false;
      }
      final now = FieldValue.serverTimestamp();
      await ref.set({
        'name': _name(profile, user.uid),
        if (profile.country.length == 2) 'country': profile.country,
        'score': 0,
        'correct': 0,
        'finished': false,
        'startedAt': now,
        'dayStart': Timestamp.fromDate(start),
        'updatedAt': now,
      });
      await _markPlayed();
      _runStartedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('Reto diario: no se pudo empezar: $e');
      return false;
    }
  }

  /// Entrega la puntuación y da el premio (una vez al día).
  /// Devuelve si se guardó en la clasificación.
  static Future<bool> submit({required int score, required int correct}) async {
    AnalyticsService.dailyChallenge(score, correct);
    final started = _runStartedAt;
    if (started != null) {
      final wait = minRunTime - DateTime.now().difference(started);
      if (!wait.isNegative) await Future.delayed(wait);
    }
    // El premio se da aunque falle la nube: el jugador sí ha jugado.
    final profile = await SaveService.loadPlayerData();
    profile.coins += coinsFor(correct);
    profile.gems += gemsFor(correct);
    await SaveService.savePlayerData(profile);
    try {
      final user = await _user();
      if (user == null) return false;
      await _ref(dayStart(), user.uid).update({
        'score': score.clamp(0, maxScore),
        'correct': correct.clamp(0, questionCount),
        'finished': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Reto diario: no se pudo entregar: $e');
      return false;
    }
  }

  /// Clasificación de hoy (los [rankingSize] primeros).
  static Future<List<Map<String, dynamic>>> ranking() async {
    try {
      await _user();
      final snapshot = await _db
          .collection('daily')
          .doc(dayId(dayStart()))
          .collection('entries')
          .orderBy('score', descending: true)
          .limit(rankingSize)
          .get();
      return [
        for (final doc in snapshot.docs)
          if (doc.data()['finished'] == true) {...doc.data(), 'uid': doc.id},
      ];
    } catch (e) {
      debugPrint('Reto diario: no se pudo cargar la clasificación: $e');
      return [];
    }
  }

  /// Mi puesto de hoy (los empates comparten puesto).
  static Future<int?> rankOf(int score) async {
    try {
      final result = await _db
          .collection('daily')
          .doc(dayId(dayStart()))
          .collection('entries')
          .where('score', isGreaterThan: score)
          .count()
          .get();
      return (result.count ?? 0) + 1;
    } catch (e) {
      debugPrint('Reto diario: no se pudo calcular el puesto: $e');
      return null;
    }
  }

  /// Borrado de datos: mis resultados de hoy y de ayer (los de antes ya no
  /// se muestran en ningún sitio).
  static Future<void> deleteMyEntries(String uid) async {
    final today = dayStart();
    for (final day in [today, today.subtract(const Duration(days: 1))]) {
      await _ref(day, uid).delete();
    }
  }
}
