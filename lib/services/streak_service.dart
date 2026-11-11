import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';
import 'analytics_service.dart';
import 'quest_service.dart';
import 'save_service.dart';

/// Premio de un día de la racha.
typedef StreakReward = ({int coins, int gems, int hints, int potions, int keys});

/// Estado de la racha al abrir el juego.
class StreakStatus {
  const StreakStatus({required this.day, required this.canClaim, required this.lost});

  /// Día de la racha (1..7) que se puede reclamar hoy, o el que ya se
  /// reclamó hoy si [canClaim] es false.
  final int day;

  /// Si hoy todavía no se ha reclamado.
  final bool canClaim;

  /// Si el jugador tenía racha y la perdió por saltarse un día.
  final bool lost;
}

/// RACHA DE 7 DÍAS
///
/// Cada día que el jugador entra puede reclamar el premio del día siguiente
/// de su racha. Si se salta un día, vuelve al día 1. Tras el día 7 empieza
/// otra vez. Es el gancho para volver cada día: el premio crece y el día 7
/// es el gordo, así que perder la racha "duele".
///
/// Se guarda en el teléfono (como los cofres por video). Si el jugador
/// cambia de teléfono, empieza de nuevo la racha, pero no pierde nada más.
class StreakService {
  StreakService._();

  static const _dayKey = 'streak_day';
  static const _lastKey = 'streak_last';

  static const List<StreakReward> rewards = [
    (coins: 50, gems: 0, hints: 0, potions: 0, keys: 0),
    (coins: 0, gems: 0, hints: 2, potions: 0, keys: 0),
    (coins: 100, gems: 0, hints: 0, potions: 0, keys: 0),
    (coins: 0, gems: 0, hints: 0, potions: 2, keys: 0),
    (coins: 150, gems: 1, hints: 0, potions: 0, keys: 0),
    (coins: 0, gems: 2, hints: 1, potions: 1, keys: 0),
    // Día 7: el gran premio.
    (coins: 300, gems: 3, hints: 0, potions: 0, keys: 1),
  ];

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static Future<StreakStatus> status() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDay = prefs.getInt(_dayKey) ?? 0;
      final last = prefs.getString(_lastKey);
      final now = DateTime.now();
      final today = _key(now);
      final yesterday = _key(now.subtract(const Duration(days: 1)));
      if (last == today) return StreakStatus(day: lastDay, canClaim: false, lost: false);
      if (last == yesterday) {
        return StreakStatus(day: lastDay % rewards.length + 1, canClaim: true, lost: false);
      }
      return StreakStatus(day: 1, canClaim: true, lost: last != null && lastDay > 0);
    } catch (_) {
      return const StreakStatus(day: 1, canClaim: false, lost: false);
    }
  }

  /// Da el premio del día al jugador y lo guarda. Devuelve el premio dado,
  /// o null si hoy ya estaba reclamado.
  static Future<StreakReward?> claim(PlayerProfile profile) async {
    final s = await status();
    if (!s.canClaim) return null;
    final r = rewards[s.day - 1];
    profile.coins += r.coins;
    profile.gems += r.gems;
    profile.letterHints += r.hints;
    profile.healthPotions += r.potions;
    profile.goldenKeys += r.keys;
    await SaveService.savePlayerData(profile);
    if (s.day == rewards.length) QuestService.track(QuestEvent.streakCompleted);
    AnalyticsService.streakClaim(s.day);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dayKey, s.day);
      await prefs.setString(_lastKey, _key(DateTime.now()));
    } catch (_) {}
    return r;
  }
}
