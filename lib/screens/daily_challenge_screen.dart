import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/victory_fx.dart';
import 'challenge_run_screen.dart';

/// Pantalla del RETO DIARIO: mi resultado de hoy, cuánto falta para el
/// siguiente, el botón de jugar y la clasificación del día.
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _played = false;
  DailyEntry? _entry;
  int? _rank;
  List<Map<String, dynamic>> _ranking = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final played = await DailyChallengeService.playedToday();
    final entry = await DailyChallengeService.myEntry();
    final ranking = await DailyChallengeService.ranking();
    final rank = entry != null && entry.finished ? await DailyChallengeService.rankOf(entry.score) : null;
    if (!mounted) return;
    setState(() {
      _played = played || entry != null;
      _entry = entry;
      _ranking = ranking;
      _rank = rank;
      _loading = false;
    });
  }

  String _timeLeftText() {
    final left = DailyChallengeService.timeLeft();
    return context.l10n.dailyNextIn(left.inHours, left.inMinutes % 60);
  }

  Future<void> _play() async {
    if (_busy || _played) return;
    AudioService.playButtonClick();
    setState(() => _busy = true);
    final profile = await SaveService.loadPlayerData();
    final ok = await DailyChallengeService.start(profile);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.dailyNeedsInternet)));
      await _load();
      return;
    }
    final questions = DailyChallengeService.questionsToday();
    final result = await Navigator.of(context).push<ChallengeResult>(
      MaterialPageRoute(
        builder: (_) => ChallengeRunScreen(
          nextQuestion: (i, _) => i < questions.length ? questions[i] : null,
          seconds: DailyChallengeService.secondsPerQuestion,
          headerLabel: (context, i, _) => context.l10n.tournamentQuestionOf(i + 1, questions.length),
          exitBody: context.l10n.dailyExitBody,
        ),
      ),
    );
    AudioService.playMenuMusic();
    final r = result ?? const ChallengeResult(score: 0, correct: 0, answered: 0);
    if (!mounted) return;
    setState(() => _busy = true);
    final saved = await DailyChallengeService.submit(score: r.score, correct: r.correct);
    QuestService.track(QuestEvent.dailyChallenge);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    await _showResult(r, saved);
  }

  Future<void> _showResult(ChallengeResult r, bool saved) {
    final coins = DailyChallengeService.coinsFor(r.correct);
    final gems = DailyChallengeService.gemsFor(r.correct);
    final perfect = r.correct >= DailyChallengeService.questionCount;
    perfect ? AudioService.playRecord() : AudioService.playVictorySound();
    return showVictoryDialog<void>(
      context: context,
      confetti: perfect,
      builder: (dialogContext) => Panel3D(
        accent: WM.gold,
        glow: 0.6,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedGameText(
              perfect ? context.l10n.dailyPerfect : context.l10n.tournamentRunDone,
              size: 24,
              colors: const [Color(0xFFFFF1B0), WM.gold],
            ),
            const SizedBox(height: 8),
            OutlinedGameText('${r.score}', size: 44),
            Text(
              context.l10n.tournamentRunSummary(r.correct, DailyChallengeService.questionCount),
              style: GoogleFonts.oswald(color: Colors.white70, fontSize: 15),
            ),
            if (_rank != null)
              Text(
                context.l10n.dailyYourRank(_rank!),
                style: GoogleFonts.oswald(color: WM.cyan, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                CountUpChip(emoji: '🪙', value: coins, delay: const Duration(milliseconds: 400), sound: true),
                if (gems > 0)
                  CountUpChip(
                    emoji: '💎',
                    value: gems,
                    accent: WM.violet,
                    delay: const Duration(milliseconds: 700),
                  ),
              ],
            ),
            if (!saved) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.tournamentSaveFailed,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(color: const Color(0xFFFFB3BA), fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: Pressable3D(
                onTap: () => Navigator.of(dialogContext).pop(),
                color: WM.cyan,
                height: 46,
                child: OutlinedGameText(context.l10n.gotIt, size: 17, font: GameFont.oswald),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: context.l10n.dailyTitle),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: WM.cyan))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                          children: [
                            EntranceFlip(index: 0, child: _buildMyPanel()),
                            const SizedBox(height: 14),
                            EntranceFlip(
                              index: 1,
                              child: ChallengeRanking(
                                title: context.l10n.dailyRankingTitle,
                                entries: _ranking,
                                valueKey: 'score',
                                emptyText: context.l10n.dailyRankingEmpty,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyPanel() {
    final entry = _entry;
    return Panel3D(
      accent: const Color(0xFF3DDC97),
      glow: _played ? 0 : 0.5,
      radius: 20,
      child: Column(
        children: [
          Row(
            children: [
              const Socket3D(size: 60, color: Color(0xFF3DDC97), child: Text('📅', style: TextStyle(fontSize: 28))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedGameText(
                      context.l10n.dailyHeadline,
                      size: 20,
                      colors: const [Color(0xFFD8FFE9), Color(0xFF3DDC97)],
                    ),
                    const SizedBox(height: 2),
                    Text(_timeLeftText(), style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: challengeStat('⭐', context.l10n.dailyScore, entry == null ? '—' : '${entry.score}')),
              const SizedBox(width: 8),
              Expanded(child: challengeStat('📊', context.l10n.tournamentRank, _rank == null ? '—' : '#$_rank')),
              const SizedBox(width: 8),
              Expanded(
                child: challengeStat(
                  '✅',
                  context.l10n.dailyCorrect,
                  entry == null ? '—' : '${entry.correct}/${DailyChallengeService.questionCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.dailyRules(
              DailyChallengeService.questionCount,
              DailyChallengeService.secondsPerQuestion,
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Pressable3D(
              onTap: _played || _busy ? null : _play,
              color: const Color(0xFF3DDC97),
              height: 52,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3, color: WM.outline),
                    )
                  : OutlinedGameText(
                      _played ? context.l10n.dailyDone : context.l10n.dailyPlay,
                      size: 18,
                      font: GameFont.oswald,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
