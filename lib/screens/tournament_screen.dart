import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/countries.dart';
import '../l10n/l10n.dart';
import '../models/player_profile.dart';
import '../models/question.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/save_service.dart';
import '../services/tournament_service.dart';
import '../services/vibration_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/game_icon.dart';

/// Nombre traducido de una liga.
String leagueName(BuildContext context, League league) => switch (league) {
      League.bronze => context.l10n.leagueBronze,
      League.silver => context.l10n.leagueSilver,
      League.gold => context.l10n.leagueGold,
      League.diamond => context.l10n.leagueDiamond,
    };

/// Muestra el premio de la semana pasada (si lo hay). Se llama desde la
/// portada y desde el torneo.
Future<void> showTournamentPrize(BuildContext context, TournamentPrize prize) {
  final trophy = switch (prize.place) {
    TournamentPlace.gold => '🏆',
    TournamentPlace.silver => '🥈',
    TournamentPlace.bronze => '🥉',
    TournamentPlace.participant => '🎖️',
  };
  AudioService.playVictorySound();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Panel3D(
        accent: WM.gold,
        glow: 0.9,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedGameText(
              context.l10n.tournamentResultTitle,
              size: 22,
              colors: const [Color(0xFFFFF1B0), WM.gold],
            ),
            const SizedBox(height: 8),
            Text(trophy, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 6),
            Text(
              context.l10n.tournamentResultBody(prize.rank, leagueName(context, prize.league)),
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                Chip3D(emoji: '🪙', text: '+${prize.coins}', accent: WM.gold, fontSize: 15),
                if (prize.gems > 0)
                  Chip3D(emoji: '💎', text: '+${prize.gems}', accent: WM.cyan, fontSize: 15),
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
    ),
  );
}

// =====================================================================
// PANTALLA PRINCIPAL DEL TORNEO
// =====================================================================
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  PlayerProfile? _profile;
  League _league = League.bronze;
  TournamentEntry? _entry;
  int _allowed = TournamentService.freeAttempts;
  int _videoAttempts = 0;
  List<Map<String, dynamic>> _ranking = [];
  int? _myRank;
  bool _loading = true;
  bool _busy = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load(claimPrize: true);
    // Refresca la cuenta atrás cada minuto.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load({bool claimPrize = false}) async {
    setState(() => _loading = true);
    if (claimPrize) {
      final prize = await TournamentService.claimLastWeekPrize();
      if (prize != null && mounted) await showTournamentPrize(context, prize);
    }
    final profile = await SaveService.loadPlayerData();
    final start = TournamentService.weekStart();
    final entry = await TournamentService.entryFor(start);
    // La liga se fija con la primera partida de la semana.
    final league = entry?.league ?? League.forStars(profile.totalStars);
    final ranking = await TournamentService.ranking(start, league);
    final rank = entry != null && entry.score > 0
        ? await TournamentService.rankOf(start, league, entry.score)
        : null;
    final videos = await TournamentService.videoAttempts();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _entry = entry;
      _league = league;
      _ranking = ranking;
      _myRank = rank;
      _videoAttempts = videos;
      _allowed = TournamentService.freeAttempts + videos;
      _loading = false;
    });
  }

  int get _used => _entry?.attempts ?? 0;
  bool get _canPlay => _used < _allowed;
  bool get _canWatchVideo =>
      !_canPlay && _videoAttempts < TournamentService.maxVideoAttempts;

  Future<void> _play() async {
    final profile = _profile;
    if (_busy || profile == null || !_canPlay) return;
    setState(() => _busy = true);
    final attempt = await TournamentService.startAttempt(profile, _league);
    if (!mounted) return;
    setState(() => _busy = false);
    if (attempt == null) {
      _snack(context.l10n.tournamentOffline);
      return;
    }
    AudioService.stopBgm();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentRunScreen(league: _league, attempt: attempt),
      ),
    );
    AudioService.playMenuMusic();
    _load();
  }

  Future<void> _watchVideo() async {
    if (_busy) return;
    setState(() => _busy = true);
    final earned = await AdService.showRewardedAd(placement: 'tournament');
    if (earned) await TournamentService.addVideoAttempt();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!earned) {
      _snack(context.l10n.noAdsNow);
      return;
    }
    AudioService.playCoins();
    _load();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _timeLeftText() {
    final left = TournamentService.timeLeft();
    if (left.inDays >= 1) return context.l10n.tournamentEndsDays(left.inDays, left.inHours % 24);
    return context.l10n.tournamentEndsHours(left.inHours, left.inMinutes % 60);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: context.l10n.tournamentTitle),
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
                            EntranceFlip(index: 1, child: _buildPrizes()),
                            const SizedBox(height: 14),
                            EntranceFlip(index: 2, child: _buildRanking()),
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
    final best = _entry?.score ?? 0;
    return Panel3D(
      accent: WM.gold,
      glow: _canPlay ? 0.5 : 0,
      radius: 20,
      child: Column(
        children: [
          Row(
            children: [
              Socket3D(
                size: 60,
                color: WM.gold,
                child: GameIcon(_league.emoji, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedGameText(
                      context.l10n.leagueLabel(leagueName(context, _league)),
                      size: 20,
                      colors: const [Color(0xFFFFF1B0), WM.gold],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeLeftText(),
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
              Expanded(child: _stat('🏅', context.l10n.tournamentBest, '$best')),
              const SizedBox(width: 8),
              Expanded(child: _stat('📊', context.l10n.tournamentRank, _myRank == null ? '—' : '#$_myRank')),
              const SizedBox(width: 8),
              Expanded(child: _stat('🎟️', context.l10n.tournamentAttempts, '$_used/$_allowed')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.tournamentRules(
              TournamentService.questionsPerRun,
              TournamentService.secondsPerQuestion,
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _canPlay
                ? Pulse(
                    amount: 0.03,
                    child: Pressable3D(
                      onTap: _busy ? null : _play,
                      color: WM.gold,
                      height: 54,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 3, color: WM.outline),
                            )
                          : OutlinedGameText(
                              context.l10n.tournamentPlay(_used + 1),
                              size: 19,
                              font: GameFont.oswald,
                            ),
                    ),
                  )
                : _canWatchVideo
                    ? Pressable3D(
                        onTap: _busy ? null : _watchVideo,
                        color: WM.cyan,
                        height: 54,
                        child: OutlinedGameText(
                          '📺 ${context.l10n.tournamentExtraAttempt}',
                          size: 17,
                          font: GameFont.oswald,
                        ),
                      )
                    : Text(
                        context.l10n.tournamentNoAttempts,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.oswald(color: WM.gold, fontSize: 14),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: WM.outline.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: Column(
        children: [
          GameIcon(emoji, size: 18),
          OutlinedGameText(value, size: 18, font: GameFont.oswald),
          Text(label, style: GoogleFonts.oswald(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPrizes() {
    Widget row(String emoji, String label, TournamentPlace place) {
      final prize = TournamentService.prizeFor(place, _league);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            GameIcon(emoji, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: GoogleFonts.oswald(color: Colors.white, fontSize: 14)),
            ),
            GameText(
              prize.gems > 0 ? '${prize.coins} 🪙  ${prize.gems} 💎' : '${prize.coins} 🪙',
              style: GoogleFonts.oswald(color: WM.gold, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Panel3D(
      accent: WM.violet,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedGameText(context.l10n.tournamentPrizesTitle, size: 16, font: GameFont.oswald),
          const SizedBox(height: 6),
          row('🏆', context.l10n.tournamentPrizeGold, TournamentPlace.gold),
          row('🥈', context.l10n.tournamentPrizeSilver, TournamentPlace.silver),
          row('🥉', context.l10n.tournamentPrizeBronze, TournamentPlace.bronze),
          row('🎖️', context.l10n.tournamentPrizeParticipant, TournamentPlace.participant),
          const SizedBox(height: 4),
          Text(
            context.l10n.tournamentPrizesNote,
            style: GoogleFonts.oswald(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRanking() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Panel3D(
      accent: WM.cyan,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedGameText(
            context.l10n.tournamentRankingTitle(leagueName(context, _league)),
            size: 16,
            font: GameFont.oswald,
          ),
          const SizedBox(height: 8),
          if (_ranking.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.l10n.tournamentEmpty,
                style: GoogleFonts.oswald(color: Colors.white60, fontSize: 14),
              ),
            ),
          for (var i = 0; i < _ranking.length; i++) _rankRow(i, _ranking[i], myUid),
        ],
      ),
    );
  }

  Widget _rankRow(int index, Map<String, dynamic> item, String? myUid) {
    final mine = item['uid'] == myUid;
    final medal = switch (index) { 0 => '🏆', 1 || 2 => '🥈', < 10 => '🥉', _ => '' };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: mine ? WM.gold.withValues(alpha: 0.18) : WM.outline.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mine ? WM.gold : Colors.white12, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#${index + 1}',
              style: GoogleFonts.anton(color: mine ? WM.gold : Colors.white70, fontSize: 15),
            ),
          ),
          SizedBox(width: 22, child: GameIcon(medal, size: 15)),
          Text(Countries.flag(item['country'] as String?), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item['name'] as String? ?? '?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 15,
                fontWeight: mine ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '${item['score'] ?? 0}',
            style: GoogleFonts.anton(color: WM.cyan, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// UNA PARTIDA DEL TORNEO: 10 preguntas contra el reloj
// =====================================================================
class TournamentRunScreen extends StatefulWidget {
  const TournamentRunScreen({super.key, required this.league, required this.attempt});

  final League league;
  final int attempt;

  @override
  State<TournamentRunScreen> createState() => _TournamentRunScreenState();
}

class _TournamentRunScreenState extends State<TournamentRunScreen> {
  late final List<Question> _questions =
      TournamentService.questionsFor(widget.league, widget.attempt);
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _correct = 0;
  int? _selected;
  int _lastPoints = 0;
  bool _finished = false;

  /// Décimas de segundo que quedan en la pregunta actual.
  int _tenths = TournamentService.secondsPerQuestion * 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AudioService.playBattleMusic();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Question? get _question => _index < _questions.length ? _questions[_index] : null;

  void _startTimer() {
    _timer?.cancel();
    _tenths = TournamentService.secondsPerQuestion * 10;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _selected != null) return;
      setState(() => _tenths--);
      if (_tenths <= 0) _answer(-1); // se acabó el tiempo
    });
  }

  void _answer(int option) {
    final q = _question;
    if (q == null || _selected != null) return;
    _timer?.cancel();
    final correct = option == q.correctIndex;
    if (correct) {
      _streak++;
      _correct++;
      AudioService.playSuccess();
      VibrationService.hit();
    } else {
      _streak = 0;
      AudioService.playWrong();
      VibrationService.hit(strong: true);
    }
    final points = TournamentService.pointsFor(
      correct: correct,
      secondsLeft: (_tenths / 10).floor(),
      streak: correct ? _streak - 1 : 0,
    );
    setState(() {
      _selected = option;
      _lastPoints = points;
      _score += points;
    });
    Future.delayed(const Duration(milliseconds: 1100), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _lastPoints = 0;
    });
    _startTimer();
  }

  Future<void> _finish() async {
    if (_finished) return;
    setState(() => _finished = true);
    final saved = await TournamentService.submitScore(widget.league, _score);
    if (!mounted) return;
    saved ? AudioService.playVictorySound() : AudioService.playDefeatSound();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Panel3D(
          accent: WM.gold,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedGameText(
                context.l10n.tournamentRunDone,
                size: 22,
                colors: const [Color(0xFFFFF1B0), WM.gold],
              ),
              const SizedBox(height: 10),
              OutlinedGameText('$_score', size: 44),
              Text(
                context.l10n.tournamentRunSummary(_correct, _questions.length),
                style: GoogleFonts.oswald(color: Colors.white70, fontSize: 15),
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
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Salir a mitad: el intento ya está gastado (se avisa antes).
  Future<bool> _confirmExit() async {
    if (_finished) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D36),
        title: Text(
          context.l10n.tournamentExitTitle,
          style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          context.l10n.tournamentExitBody,
          style: GoogleFonts.oswald(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.tournamentKeepPlaying),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.tournamentLeave),
          ),
        ],
      ),
    );
    if (leave == true) {
      _timer?.cancel();
      _finished = true;
      // Se entrega lo conseguido hasta ahora.
      unawaited(TournamentService.submitScore(widget.league, _score));
    }
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: WM.outline,
        body: GameBackground(
          child: SafeArea(
            child: q == null
                ? Center(
                    child: Text(
                      context.l10n.tournamentNoQuestions,
                      style: GoogleFonts.oswald(color: Colors.white70),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTop(),
                        const SizedBox(height: 10),
                        _buildTimer(),
                        const SizedBox(height: 14),
                        Panel3D(
                          accent: WM.violet,
                          radius: 18,
                          child: Column(
                            children: [
                              Text(
                                q.category.toUpperCase(),
                                style: GoogleFonts.oswald(
                                  color: WM.cyan,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                q.prompt,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.oswald(color: Colors.white, fontSize: 19),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (var i = 0; i < q.options.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _option(q, i),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTop() {
    return Row(
      children: [
        Pressable3D(
          onTap: () async {
            if (await _confirmExit() && mounted) Navigator.of(context).pop();
          },
          color: const Color(0xFF3A2A7A),
          height: 40,
          depth: 5,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: const Icon(Icons.close_rounded, color: WM.bone, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedGameText(
            context.l10n.tournamentQuestionOf(_index + 1, _questions.length),
            size: 17,
            font: GameFont.oswald,
          ),
        ),
        if (_streak >= 2) ...[
          Chip3D(emoji: '🔥', text: 'x$_streak', accent: const Color(0xFFFF8A3D), fontSize: 14),
          const SizedBox(width: 6),
        ],
        Chip3D(emoji: '⭐', text: '$_score', accent: WM.gold, fontSize: 16),
      ],
    );
  }

  Widget _buildTimer() {
    if (_finished) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: WM.cyan),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.tournamentSaving,
            style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
    }
    final total = TournamentService.secondsPerQuestion * 10;
    final value = (_tenths / total).clamp(0.0, 1.0);
    final color = value > 0.5
        ? WM.cyan
        : value > 0.25
            ? WM.gold
            : const Color(0xFFFF5A6E);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: WM.outline,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (_selected != null && _lastPoints > 0)
          OutlinedGameText('+$_lastPoints', size: 14, font: GameFont.oswald),
      ],
    );
  }

  Widget _option(Question q, int i) {
    final answered = _selected != null;
    final isCorrect = i == q.correctIndex;
    final isSelected = i == _selected;
    Color disabled = const Color(0xFF3A3452);
    if (answered && isCorrect) {
      disabled = const Color(0xFF2FC22A);
    } else if (answered && isSelected) {
      disabled = const Color(0xFFE0344A);
    }
    return Pressable3D(
      onTap: answered ? null : () => _answer(i),
      color: const Color(0xFF5B3FC4),
      disabledColor: disabled,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        q.options[i],
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.oswald(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
