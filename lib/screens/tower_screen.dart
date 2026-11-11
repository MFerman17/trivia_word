import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/quest_service.dart';
import '../services/tower_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/victory_fx.dart';
import 'challenge_run_screen.dart';

/// Pantalla de la TORRE INFINITA: mi récord, subidas que quedan hoy, el
/// botón de subir y la clasificación de récords.
class TowerScreen extends StatefulWidget {
  const TowerScreen({super.key});

  @override
  State<TowerScreen> createState() => _TowerScreenState();
}

class _TowerScreenState extends State<TowerScreen> {
  bool _loading = true;
  bool _busy = false;
  int _best = 0;
  int? _rank;
  int _runsLeft = 0;
  int _videos = 0;
  List<Map<String, dynamic>> _ranking = [];

  static const Color _accent = Color(0xFFB07CFF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final best = await TowerService.localBest();
    final runs = await TowerService.runsToday();
    final left = await TowerService.runsLeft();
    final ranking = await TowerService.ranking();
    final rank = await TowerService.rankOf(best);
    if (!mounted) return;
    setState(() {
      _best = best;
      _runsLeft = left;
      _videos = runs.videos;
      _ranking = ranking;
      _rank = rank;
      _loading = false;
    });
  }

  bool get _canWatchVideo => _runsLeft == 0 && _videos < TowerService.videoRunsPerDay;

  Future<void> _watchVideo() async {
    if (_busy) return;
    setState(() => _busy = true);
    final earned = await AdService.showRewardedAd(placement: 'tower');
    if (earned) await TowerService.addVideoRun();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!earned) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.noAdsNow)));
    }
    await _load();
  }

  Future<void> _climb() async {
    if (_busy || _runsLeft <= 0) return;
    AudioService.playButtonClick();
    await TowerService.useRun();
    if (!mounted) return;
    final used = <String>{};
    final result = await Navigator.of(context).push<ChallengeResult>(
      MaterialPageRoute(
        builder: (_) => ChallengeRunScreen(
          // Cada acierto sube un piso; la pregunta es la del piso al que se
          // intenta subir (fallar no sube, pero la siguiente es otra).
          nextQuestion: (_, correct) => TowerService.questionFor(correct + 1, used),
          seconds: TowerService.secondsPerQuestion,
          lives: TowerService.lives,
          headerLabel: (context, _, correct) => context.l10n.towerFloor(correct + 1),
          exitBody: context.l10n.towerExitBody,
        ),
      ),
    );
    AudioService.playMenuMusic();
    final floors = result?.correct ?? 0;
    if (!mounted) return;
    setState(() => _busy = true);
    final record = await TowerService.finishRun(floors);
    QuestService.track(QuestEvent.towerFloors, amount: floors);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    await _showResult(floors, record);
  }

  Future<void> _showResult(int floors, bool record) {
    final coins = TowerService.coinsFor(floors);
    final gems = TowerService.gemsFor(floors);
    record ? AudioService.playRecord() : AudioService.playLevelUp();
    return showVictoryDialog<void>(
      context: context,
      confetti: record,
      builder: (dialogContext) => Panel3D(
        accent: _accent,
        glow: 0.6,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedGameText(
              record ? context.l10n.towerNewRecord : context.l10n.towerRunOver,
              size: 24,
              colors: const [Color(0xFFEBDDFF), _accent],
            ),
            const SizedBox(height: 8),
            OutlinedGameText('$floors', size: 48),
            Text(
              context.l10n.towerFloorsClimbed,
              style: GoogleFonts.oswald(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (coins > 0)
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
              GameHeader(title: context.l10n.towerTitle),
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
                                title: context.l10n.towerRankingTitle,
                                entries: _ranking,
                                valueKey: 'bestFloor',
                                emptyText: context.l10n.towerRankingEmpty,
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
    final canClimb = _runsLeft > 0;
    return Panel3D(
      accent: _accent,
      glow: canClimb ? 0.5 : 0,
      radius: 20,
      child: Column(
        children: [
          Row(
            children: [
              const Socket3D(size: 60, color: _accent, child: Text('🗼', style: TextStyle(fontSize: 28))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedGameText(
                      context.l10n.towerHeadline,
                      size: 20,
                      colors: const [Color(0xFFEBDDFF), _accent],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.towerSubtitle,
                      style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: challengeStat('🏆', context.l10n.towerBest, '$_best')),
              const SizedBox(width: 8),
              Expanded(child: challengeStat('📊', context.l10n.tournamentRank, _rank == null ? '—' : '#$_rank')),
              const SizedBox(width: 8),
              Expanded(child: challengeStat('🎟️', context.l10n.towerRunsLeft, '$_runsLeft')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.towerRules(TowerService.lives, TowerService.secondsPerQuestion),
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: canClimb
                ? Pressable3D(
                    onTap: _busy ? null : _climb,
                    color: _accent,
                    height: 52,
                    child: OutlinedGameText(context.l10n.towerClimb, size: 18, font: GameFont.oswald),
                  )
                : Pressable3D(
                    onTap: _canWatchVideo && !_busy ? _watchVideo : null,
                    color: WM.gold,
                    height: 52,
                    child: OutlinedGameText(
                      _canWatchVideo ? context.l10n.towerVideoRun : context.l10n.towerComeBack,
                      size: 16,
                      font: GameFont.oswald,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
