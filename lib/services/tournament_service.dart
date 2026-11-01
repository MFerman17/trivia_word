import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';
import '../models/question.dart';
import 'cloud_service.dart';
import 'question_repository.dart';
import 'save_service.dart';

/// Ligas del torneo. Cada jugador compite SOLO contra los de su liga, que se
/// decide por las estrellas que tiene en el mapa: así un jugador nuevo no
/// compite contra uno que ya terminó el juego ("dificultad nivelada").
/// Cada liga, además, usa preguntas de una dificultad distinta.
enum League {
  bronze('🥉', 0, 2),
  silver('🥈', 60, 3),
  gold('🥇', 150, 4),
  diamond('💎', 260, 5);

  const League(this.emoji, this.minStars, this.difficulty);
  final String emoji;
  final int minStars;
  final int difficulty;

  /// Los premios suben con la liga.
  double get prizeMultiplier => switch (this) {
        League.bronze => 1.0,
        League.silver => 1.5,
        League.gold => 2.0,
        League.diamond => 3.0,
      };

  static League forStars(int stars) {
    var league = League.bronze;
    for (final l in League.values) {
      if (stars >= l.minStars) league = l;
    }
    return league;
  }

  static League? byName(String? name) =>
      League.values.where((l) => l.name == name).firstOrNull;
}

/// Puesto al cerrar la semana.
enum TournamentPlace { gold, silver, bronze, participant }

class TournamentPrize {
  const TournamentPrize({
    required this.place,
    required this.rank,
    required this.league,
    required this.coins,
    required this.gems,
  });
  final TournamentPlace place;
  final int rank;
  final League league;
  final int coins;
  final int gems;
}

/// Mi inscripción de esta semana.
class TournamentEntry {
  const TournamentEntry({
    required this.league,
    required this.score,
    required this.attempts,
    required this.finished,
  });
  final League league;
  final int score; // mejor puntuación de la semana
  final int attempts; // intentos empezados
  final bool finished; // el último intento ya se entregó
}

/// TORNEO SEMANAL
///
/// Funciona con el plan GRATIS de Firebase, que no permite tener código en el
/// servidor. Por eso:
///  - La semana va de lunes a domingo en hora UTC (igual para todo el mundo).
///  - Todos los de una liga reciben las MISMAS preguntas en cada intento
///    (mismas preguntas del intento 1, mismas del 2...), así es justo.
///  - Cada intento se registra en la nube AL EMPEZAR (si sales a mitad, el
///    intento ya cuenta: no se puede "reintentar" un mal intento).
///  - Las reglas de Firestore controlan que la puntuación sea posible, que
///    entre empezar y entregar pasen al menos 20 s y que no se pueda escribir
///    fuera de la semana. No es a prueba de todo (eso exigiría servidor),
///    pero frena las trampas fáciles.
///  - Los premios no los reparte un servidor: al abrir el juego la semana
///    siguiente, cada teléfono mira en qué puesto quedó (la clasificación ya
///    no se puede cambiar) y cobra su premio una sola vez.
///
/// Estructura en Firestore:
///   tournaments/{semana}/leagues/{liga}/entries/{uid}
class TournamentService {
  TournamentService._();

  static const int questionsPerRun = 10;
  static const int secondsPerQuestion = 15;
  static const int freeAttempts = 3;
  static const int maxVideoAttempts = 2;
  static const int maxAttempts = freeAttempts + maxVideoAttempts;

  // Puntos: acierto 100 + rapidez (5 por segundo sobrante, máx. 75)
  // + racha (10 por acierto seguido, máx. 50). 10 preguntas = máx. 2250.
  static const int basePoints = 100;
  static const int pointsPerSecond = 5;
  static const int streakPoints = 10;
  static const int maxStreakBonus = 50;
  static const int maxScore =
      questionsPerRun * (basePoints + secondsPerQuestion * pointsPerSecond + maxStreakBonus);

  /// Cuántos jugadores se muestran en la clasificación.
  static const int rankingSize = 50;

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Las reglas exigen al menos [minRunTime] entre empezar y entregar (un
  /// intento real no puede ser más rápido). Si alguien contesta rapidísimo,
  /// la entrega simplemente espera lo que falte.
  static const Duration minRunTime = Duration(seconds: 22);
  static DateTime? _runStartedAt;

  // ------------------------------------------------------------------
  // SEMANA
  // ------------------------------------------------------------------

  /// Lunes a las 00:00 UTC de la semana de [now].
  static DateTime weekStart([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    final day = DateTime.utc(n.year, n.month, n.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime previousWeekStart() => weekStart().subtract(const Duration(days: 7));

  static DateTime weekEnd([DateTime? now]) => weekStart(now).add(const Duration(days: 7));

  /// Id de la semana en la nube: los milisegundos de su lunes. Las reglas de
  /// Firestore lo comprueban con la fecha que va dentro del documento.
  static String weekId(DateTime start) => start.millisecondsSinceEpoch.toString();

  static Duration timeLeft() => weekEnd().difference(DateTime.now().toUtc());

  // ------------------------------------------------------------------
  // PUNTOS Y PREGUNTAS
  // ------------------------------------------------------------------

  static int pointsFor({required bool correct, required int secondsLeft, required int streak}) {
    if (!correct) return 0;
    final speed = (secondsLeft.clamp(0, secondsPerQuestion)) * pointsPerSecond;
    final bonus = (streak * streakPoints).clamp(0, maxStreakBonus);
    return basePoints + speed + bonus;
  }

  /// Las preguntas del intento [attempt] (1, 2, 3...) de esta semana.
  static List<Question> questionsFor(League league, int attempt) {
    final days = weekStart().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final seed = days * 100 + league.index * 10 + attempt;
    return QuestionRepository.seeded(
      difficulty: league.difficulty,
      count: questionsPerRun,
      seed: seed,
    );
  }

  // ------------------------------------------------------------------
  // INTENTOS EXTRA (por video) — se guardan en el teléfono
  // ------------------------------------------------------------------

  static String _extraKey(DateTime start) => 'tournament_extra_${weekId(start)}';
  static String _leagueKey(DateTime start) => 'tournament_league_${weekId(start)}';

  static Future<int> videoAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_extraKey(weekStart())) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> addVideoAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _extraKey(weekStart());
      final current = prefs.getInt(key) ?? 0;
      if (current < maxVideoAttempts) await prefs.setInt(key, current + 1);
    } catch (_) {}
  }

  /// Intentos permitidos esta semana (3 + los ganados con video).
  static Future<int> allowedAttempts() async => freeAttempts + await videoAttempts();

  // ------------------------------------------------------------------
  // NUBE
  // ------------------------------------------------------------------

  static Future<User?> _user() => CloudService.signInAnonymously();

  static DocumentReference<Map<String, dynamic>> _entryRef(
    DateTime start,
    League league,
    String uid,
  ) =>
      _db
          .collection('tournaments')
          .doc(weekId(start))
          .collection('leagues')
          .doc(league.name)
          .collection('entries')
          .doc(uid);

  static TournamentEntry _parse(Map<String, dynamic> data, League league) => TournamentEntry(
        league: league,
        score: (data['score'] as num?)?.toInt() ?? 0,
        attempts: (data['attempts'] as num?)?.toInt() ?? 0,
        finished: data['finished'] as bool? ?? true,
      );

  /// Mi inscripción de la semana [start] (null si no jugué).
  static Future<TournamentEntry?> entryFor(DateTime start) async {
    try {
      final user = await _user();
      if (user == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final saved = League.byName(prefs.getString(_leagueKey(start)));
      // Primero la liga recordada; si no, se buscan las cuatro.
      for (final league in [?saved, ...League.values.where((l) => l != saved)]) {
        final doc = await _entryRef(start, league, user.uid).get();
        if (doc.exists && doc.data() != null) {
          await prefs.setString(_leagueKey(start), league.name);
          return _parse(doc.data()!, league);
        }
      }
    } catch (e) {
      debugPrint('Torneo: no se pudo leer la inscripción: $e');
    }
    return null;
  }

  /// Empieza un intento: lo apunta en la nube ANTES de jugar.
  /// Devuelve el número de intento (1, 2...) o null si no se pudo.
  static Future<int?> startAttempt(PlayerProfile profile, League league) async {
    final start = weekStart();
    try {
      final user = await _user();
      if (user == null) return null;
      // El ranking global debe tener las estrellas al día: las reglas lo
      // usan para comprobar que la liga es la que te corresponde.
      await CloudService.syncProfileToCloud(profile);

      final ref = _entryRef(start, league, user.uid);
      final doc = await ref.get();
      final now = FieldValue.serverTimestamp();
      if (!doc.exists) {
        await ref.set({
          'name': _name(profile, user.uid),
          if (profile.country.length == 2) 'country': profile.country,
          'league': league.name,
          'score': 0,
          'attempts': 1,
          'finished': false,
          'startedAt': now,
          'weekStart': Timestamp.fromDate(start),
          'updatedAt': now,
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_leagueKey(start), league.name);
        _runStartedAt = DateTime.now();
        return 1;
      }
      final entry = _parse(doc.data()!, league);
      if (entry.attempts >= await allowedAttempts()) return null;
      await ref.update({
        'name': _name(profile, user.uid),
        'attempts': entry.attempts + 1,
        'finished': false,
        'startedAt': now,
        'updatedAt': now,
      });
      _runStartedAt = DateTime.now();
      return entry.attempts + 1;
    } catch (e) {
      debugPrint('Torneo: no se pudo empezar el intento: $e');
      return null;
    }
  }

  /// Entrega el resultado del intento. Se guarda la MEJOR puntuación.
  static Future<bool> submitScore(League league, int runScore) async {
    final started = _runStartedAt;
    if (started != null) {
      final wait = minRunTime - DateTime.now().difference(started);
      if (!wait.isNegative) await Future.delayed(wait);
    }
    try {
      final user = await _user();
      if (user == null) return false;
      final ref = _entryRef(weekStart(), league, user.uid);
      final doc = await ref.get();
      if (!doc.exists) return false;
      final entry = _parse(doc.data()!, league);
      final best = runScore.clamp(0, maxScore) > entry.score ? runScore.clamp(0, maxScore) : entry.score;
      await ref.update({
        'score': best,
        'finished': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Torneo: no se pudo entregar la puntuación: $e');
      return false;
    }
  }

  /// Clasificación de una liga (los [rankingSize] primeros).
  static Future<List<Map<String, dynamic>>> ranking(DateTime start, League league) async {
    try {
      await _user();
      final snapshot = await _db
          .collection('tournaments')
          .doc(weekId(start))
          .collection('leagues')
          .doc(league.name)
          .collection('entries')
          .orderBy('score', descending: true)
          .limit(rankingSize)
          .get();
      return [
        for (final doc in snapshot.docs)
          if (((doc.data()['score'] as num?) ?? 0) > 0) {...doc.data(), 'uid': doc.id},
      ];
    } catch (e) {
      debugPrint('Torneo: no se pudo cargar la clasificación: $e');
      return [];
    }
  }

  /// Mi puesto: cuántos tienen MÁS puntos que yo, más uno (los empates
  /// comparten puesto).
  static Future<int?> rankOf(DateTime start, League league, int score) async {
    try {
      final result = await _db
          .collection('tournaments')
          .doc(weekId(start))
          .collection('leagues')
          .doc(league.name)
          .collection('entries')
          .where('score', isGreaterThan: score)
          .count()
          .get();
      return (result.count ?? 0) + 1;
    } catch (e) {
      debugPrint('Torneo: no se pudo calcular el puesto: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------
  // PREMIOS DE LA SEMANA PASADA
  // ------------------------------------------------------------------

  static TournamentPlace placeFor(int rank) => rank == 1
      ? TournamentPlace.gold
      : rank <= 3
          ? TournamentPlace.silver
          : rank <= 10
              ? TournamentPlace.bronze
              : TournamentPlace.participant;

  static ({int coins, int gems}) prizeFor(TournamentPlace place, League league) {
    final base = switch (place) {
      TournamentPlace.gold => (coins: 300, gems: 6),
      TournamentPlace.silver => (coins: 200, gems: 4),
      TournamentPlace.bronze => (coins: 120, gems: 2),
      TournamentPlace.participant => (coins: 40, gems: 0),
    };
    return (
      coins: (base.coins * league.prizeMultiplier).round(),
      gems: (base.gems * league.prizeMultiplier).round(),
    );
  }

  /// Si el jugador participó la semana pasada y aún no cobró, calcula su
  /// puesto, le da el premio (y la copa si quedó entre los 10 primeros) y lo
  /// devuelve para enseñarlo. Si no, devuelve null.
  static Future<TournamentPrize?> claimLastWeekPrize() async {
    final start = previousWeekStart();
    final id = weekId(start);
    try {
      final profile = await SaveService.loadPlayerData();
      if (profile.tournamentClaimed == id) return null;
      final entry = await entryFor(start);
      if (entry == null || entry.score <= 0) return null;
      final rank = await rankOf(start, entry.league, entry.score);
      if (rank == null) return null; // sin internet: se intentará otro día

      final place = placeFor(rank);
      final prize = prizeFor(place, entry.league);
      profile.coins += prize.coins;
      profile.gems += prize.gems;
      if (place != TournamentPlace.participant) {
        profile.trophies[place.name] = (profile.trophies[place.name] ?? 0) + 1;
      }
      profile.tournamentClaimed = id;
      await SaveService.savePlayerData(profile);
      await CloudService.syncProfileToCloud(profile);
      return TournamentPrize(
        place: place,
        rank: rank,
        league: entry.league,
        coins: prize.coins,
        gems: prize.gems,
      );
    } catch (e) {
      debugPrint('Torneo: no se pudo cobrar el premio: $e');
      return null;
    }
  }

  /// Borra mis inscripciones de esta semana y la anterior (borrado de datos).
  static Future<void> deleteMyEntries(String uid) async {
    for (final start in [weekStart(), previousWeekStart()]) {
      for (final league in League.values) {
        try {
          await _entryRef(start, league, uid).delete();
        } catch (_) {}
      }
    }
  }

  static String _name(PlayerProfile profile, String uid) {
    final name = profile.name.trim().isEmpty ? 'Jugador_${uid.substring(0, 5)}' : profile.name.trim();
    return String.fromCharCodes(name.runes.take(20));
  }
}
