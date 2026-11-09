import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/tournament_service.dart';
import '../services/tower_service.dart';
import '../widgets/game_3d.dart';
import 'daily_challenge_screen.dart';
import 'tournament_screen.dart';
import 'tower_screen.dart';

/// DESAFÍOS: los tres modos de competir contra otros jugadores, juntos en
/// una pantalla para no llenar la portada de botones.
///  - Reto diario: 5 preguntas, una vez al día, clasificación del día.
///  - Torre infinita: subir pisos sin fin, clasificación de récords.
///  - Torneo semanal: 10 preguntas, ligas por estrellas, premios el lunes.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  bool _dailyPlayed = true;
  int _towerRuns = 0;
  int _towerBest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final played = await DailyChallengeService.playedToday();
    final runs = await TowerService.runsLeft();
    final best = await TowerService.localBest();
    if (!mounted) return;
    setState(() {
      _dailyPlayed = played;
      _towerRuns = runs;
      _towerBest = best;
    });
  }

  Future<void> _open(Widget screen) async {
    AudioService.playButtonClick();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    AudioService.playMenuMusic();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final daily = DailyChallengeService.timeLeft();
    final week = TournamentService.timeLeft();
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: l.challengesTitle),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  children: [
                    EntranceFlip(
                      index: 0,
                      child: _tile(
                        emoji: '📅',
                        color: const Color(0xFF3DDC97),
                        title: l.dailyTitle,
                        body: l.challengesDailyBody,
                        status: _dailyPlayed
                            ? l.dailyNextIn(daily.inHours, daily.inMinutes % 60)
                            : l.challengesDailyReady,
                        highlight: !_dailyPlayed,
                        onTap: () => _open(const DailyChallengeScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    EntranceFlip(
                      index: 1,
                      child: _tile(
                        emoji: '🗼',
                        color: const Color(0xFFB07CFF),
                        title: l.towerTitle,
                        body: l.challengesTowerBody,
                        status: l.challengesTowerStatus(_towerBest, _towerRuns),
                        highlight: _towerRuns > 0,
                        onTap: () => _open(const TowerScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    EntranceFlip(
                      index: 2,
                      child: _tile(
                        emoji: '🏆',
                        color: WM.gold,
                        title: l.tournamentTitle,
                        body: l.challengesTournamentBody,
                        status: week.inDays >= 1
                            ? l.tournamentEndsDays(week.inDays, week.inHours % 24)
                            : l.tournamentEndsHours(week.inHours, week.inMinutes % 60),
                        highlight: false,
                        onTap: () => _open(const TournamentScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required String emoji,
    required Color color,
    required String title,
    required String body,
    required String status,
    required bool highlight,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Panel3D(
        accent: color,
        glow: highlight ? 0.55 : 0,
        radius: 20,
        child: Row(
          children: [
            Socket3D(size: 64, color: color, child: Text(emoji, style: const TextStyle(fontSize: 30))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedGameText(title, size: 20, colors: [Colors.white, color]),
                  const SizedBox(height: 2),
                  Text(body, style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13, height: 1.25)),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: GoogleFonts.oswald(
                      color: highlight ? color : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 30),
          ],
        ),
      ),
    );
  }
}
