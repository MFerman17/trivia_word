import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/countries.dart';
import '../l10n/l10n.dart';
import '../models/question.dart';
import '../services/audio_service.dart';
import '../services/tournament_service.dart';
import '../services/vibration_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/game_icon.dart';
import '../widgets/screen_shake.dart';

/// Lo que devuelve una partida al terminar (o al salir a mitad).
class ChallengeResult {
  const ChallengeResult({required this.score, required this.correct, required this.answered});
  final int score; // puntos (acierto + rapidez + racha), como en el torneo
  final int correct; // aciertos
  final int answered; // preguntas contestadas
}

/// PARTIDA CONTRA EL RELOJ (reto diario y Torre infinita)
///
/// Las dos usan la misma mecánica que el torneo: una pregunta cada vez, con
/// cuenta atrás, y puntos por acertar rápido y seguido. Cambia solo cuándo
/// se acaba:
///  - Reto diario: tras sus 5 preguntas ([lives] = null).
///  - Torre: cuando se pierden las [lives] vidas; las preguntas no se acaban.
/// La pantalla que la abre recibe un [ChallengeResult] y da los premios.
class ChallengeRunScreen extends StatefulWidget {
  const ChallengeRunScreen({
    super.key,
    required this.nextQuestion,
    required this.seconds,
    required this.headerLabel,
    this.lives,
    this.exitBody,
  });

  /// Pregunta número [index] (0, 1, 2...) o null si ya no hay más.
  /// [correct] son los aciertos hasta ahora (en la Torre, el piso).
  final Question? Function(int index, int correct) nextQuestion;
  final int seconds;

  /// Texto de arriba ("Pregunta 2 de 5", "Piso 7").
  final String Function(BuildContext context, int index, int correct) headerLabel;

  /// Vidas (Torre). Null = sin vidas, se juega hasta que no haya preguntas.
  final int? lives;

  /// Aviso al salir a mitad.
  final String? exitBody;

  @override
  State<ChallengeRunScreen> createState() => _ChallengeRunScreenState();
}

class _ChallengeRunScreenState extends State<ChallengeRunScreen> {
  int _index = 0;
  Question? _question;
  int _score = 0;
  int _streak = 0;
  int _correct = 0;
  int _answered = 0;
  late int _lives = widget.lives ?? 0;
  int _hitsTaken = 0;
  int? _selected;
  int _lastPoints = 0;
  bool _finished = false;
  late int _tenths = widget.seconds * 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AudioService.playBattleMusic();
    _question = widget.nextQuestion(0, 0);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _tenths = widget.seconds * 10;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _selected != null || _finished) return;
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
      if (widget.lives != null) {
        _lives--;
        _hitsTaken++;
      }
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
      _answered++;
      _lastPoints = points;
      _score += points;
    });
    Future.delayed(const Duration(milliseconds: 1100), _next);
  }

  void _next() {
    if (!mounted || _finished) return;
    final outOfLives = widget.lives != null && _lives <= 0;
    final next = outOfLives ? null : widget.nextQuestion(_index + 1, _correct);
    if (next == null) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _question = next;
      _selected = null;
      _lastPoints = 0;
    });
    _startTimer();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    Navigator.of(context).pop(ChallengeResult(score: _score, correct: _correct, answered: _answered));
  }

  /// Salir a mitad: cuenta como jugada (se avisa antes).
  Future<void> _confirmExit() async {
    if (_finished) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D36),
        title: Text(
          context.l10n.tournamentExitTitle,
          style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          widget.exitBody ?? context.l10n.tournamentExitBody,
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
    if (leave == true && mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: ScreenShake(
        trigger: _hitsTaken,
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
      ),
    );
  }

  Widget _buildTop() {
    return Row(
      children: [
        Pressable3D(
          onTap: _confirmExit,
          color: const Color(0xFF3A2A7A),
          height: 40,
          depth: 5,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: const Icon(Icons.close_rounded, color: WM.bone, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedGameText(widget.headerLabel(context, _index, _correct), size: 17, font: GameFont.oswald),
        ),
        if (widget.lives != null) ...[
          for (var i = 0; i < widget.lives!; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Opacity(
                opacity: i < _lives ? 1 : 0.25,
                child: const GameIcon('❤️', size: 15),
              ),
            ),
          const SizedBox(width: 6),
        ],
        if (_streak >= 2) ...[
          Chip3D(emoji: '🔥', text: 'x$_streak', accent: const Color(0xFFFF8A3D), fontSize: 14),
          const SizedBox(width: 6),
        ],
        Chip3D(emoji: '⭐', text: '$_score', accent: WM.gold, fontSize: 16),
      ],
    );
  }

  Widget _buildTimer() {
    final total = widget.seconds * 10;
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
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
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

// =====================================================================
// PIEZAS COMUNES DE LAS PANTALLAS DE RETO DIARIO Y TORRE
// =====================================================================

/// Casilla de dato: icono, número y etiqueta.
Widget challengeStat(String emoji, String label, String value) {
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

/// Clasificación: los primeros con su bandera y su valor ([valueKey]).
class ChallengeRanking extends StatelessWidget {
  const ChallengeRanking({
    super.key,
    required this.title,
    required this.entries,
    required this.valueKey,
    required this.emptyText,
  });

  final String title;
  final List<Map<String, dynamic>> entries;
  final String valueKey;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Panel3D(
      accent: WM.violet,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedGameText(title, size: 20, colors: const [Colors.white, WM.cyanLight]),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(color: Colors.white60, fontSize: 14),
              ),
            ),
          for (var i = 0; i < entries.length; i++) _row(i, entries[i], myUid),
        ],
      ),
    );
  }

  Widget _row(int index, Map<String, dynamic> item, String? myUid) {
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
          Text('${item[valueKey] ?? 0}', style: GoogleFonts.anton(color: WM.cyan, fontSize: 16)),
        ],
      ),
    );
  }
}
