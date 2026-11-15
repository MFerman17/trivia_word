import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/locale_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/game_icon.dart';
import 'minigame_screen.dart' show MinigameCountdown;

// =====================================================================
// MINIJUEGOS DE PALABRAS (2.ª tanda): Letras revueltas, ¿Bien escrita? y
// Serpiente de letras. Igual que los otros, cada uno avisa con
// onFinished(true/false) y la pantalla del portal entrega el premio.
// Los datos están en assets/minigames/*_es.json y *_en.json.
// =====================================================================

String get _lang => LocaleService.languageCode == 'en' ? 'en' : 'es';

Future<Map<String, dynamic>> _loadData(String name) async {
  final raw = await rootBundle.loadString('assets/minigames/${name}_$_lang.json');
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Ficha de letra con aspecto de Scrabble (la misma que la forja).
class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, this.used = false, this.onTap, this.height = 50});

  final String letter;
  final bool used;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: used ? 0.3 : 1,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF1C9), Color(0xFFE9C27A)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: WM.outline, width: 2.5),
            boxShadow: const [BoxShadow(color: WM.outline, offset: Offset(0, 4))],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(letter, style: GoogleFonts.anton(color: WM.outline, fontSize: height * 0.48)),
          ),
        ),
      ),
    );
  }
}

/// Mensaje corto bajo el tablero (verde si es bueno, rojo si no).
Widget _feedback(String? text, bool good) => SizedBox(
      height: 24,
      child: text == null
          ? null
          : Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: good ? const Color(0xFF9AF2A0) : const Color(0xFFFFB3BA),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

Widget _rules(String text) => Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
    );

// =====================================================================
// LETRAS REVUELTAS: ordenar las letras para formar la palabra, con una
// pista de su significado. 6 palabras, hay que acertar 4.
// =====================================================================
class ScrambleGame extends StatefulWidget {
  const ScrambleGame({super.key, required this.onFinished});
  final ValueChanged<bool> onFinished;

  @override
  State<ScrambleGame> createState() => _ScrambleGameState();
}

class _ScrambleGameState extends State<ScrambleGame> {
  static const int totalSeconds = 120;
  static const int rounds = 6;
  static const int goal = 4;

  final math.Random _rnd = math.Random();
  List<({String word, String hint})> _words = [];
  int _index = 0;
  int _correct = 0;
  List<String> _letters = [];
  final List<int> _picked = [];
  String? _message;
  bool _messageGood = false;
  int _seconds = totalSeconds;
  Timer? _timer;
  bool _done = false;
  bool _loading = true;

  ({String word, String hint}) get _current => _words[_index];
  String get _typed => _picked.map((i) => _letters[i]).join();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _loadData('scramble');
      final all = [
        for (final w in data['words'] as List)
          (word: (w as Map)['word'] as String, hint: w['hint'] as String),
      ]..shuffle(_rnd);
      _words = all.take(rounds).toList();
      _prepareWord();
    } catch (e) {
      debugPrint('No se pudieron cargar las letras revueltas: $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      setState(() => _seconds--);
      if (_seconds <= 0) {
        // Se acabó el tiempo: se enseña la palabra que había.
        _finish(won: _correct >= goal, reveal: true);
      }
    });
  }

  /// Desordena la palabra actual (nunca la deja en su orden correcto).
  void _prepareWord() {
    final word = _current.word;
    final letters = word.split('');
    do {
      letters.shuffle(_rnd);
    } while (letters.join() == word && word.length > 1);
    _letters = letters;
    _picked.clear();
  }

  void _tap(int i) {
    if (_done || _picked.contains(i)) return;
    AudioService.playSelect();
    setState(() {
      _picked.add(i);
      _message = null;
    });
    if (_picked.length == _letters.length) _check();
  }

  void _check() {
    if (_typed == _current.word) {
      AudioService.playSuccess();
      _correct++;
      setState(() {
        _message = context.l10n.forgeGood;
        _messageGood = true;
      });
      _next();
    } else {
      AudioService.playWrong();
      setState(() {
        _message = context.l10n.scrambleWrong;
        _messageGood = false;
        _picked.clear();
      });
    }
  }

  void _skip() {
    if (_done) return;
    AudioService.playButtonClick();
    setState(() {
      _message = context.l10n.scrambleWas(_current.word);
      _messageGood = false;
    });
    _next();
  }

  /// Siguiente palabra, o fin si ya se ganó o ya no se puede ganar.
  void _next() {
    final left = rounds - _index - 1;
    if (_correct >= goal) {
      _finish(won: true);
    } else if (_correct + left < goal || left == 0) {
      _finish(won: false);
    } else {
      setState(() {
        _index++;
        _prepareWord();
      });
    }
  }

  void _finish({required bool won, bool reveal = false}) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    if (reveal) {
      setState(() {
        _message = context.l10n.scrambleWas(_current.word);
        _messageGood = false;
      });
    }
    Future.delayed(Duration(milliseconds: reveal ? 1800 : 700), () {
      if (mounted) widget.onFinished(won);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: WM.cyan));
    if (_words.isEmpty) {
      return Center(
        child: Text(context.l10n.tournamentNoQuestions, style: GoogleFonts.oswald(color: Colors.white70)),
      );
    }
    final word = _current.word;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      child: Column(
        children: [
          _rules(context.l10n.scrambleRules(goal, rounds)),
          const SizedBox(height: 8),
          MinigameCountdown(seconds: _seconds, total: totalSeconds),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Chip3D(emoji: '✅', text: '$_correct/$goal', accent: _correct >= goal ? WM.green : WM.gold, fontSize: 15),
              Chip3D(emoji: '📜', text: '${_index + 1}/$rounds', accent: WM.cyan, fontSize: 15),
            ],
          ),
          const Spacer(),
          // La pista: qué significa la palabra.
          Panel3D(
            accent: WM.violet,
            radius: 16,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const GameIcon('💡', size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _current.hint,
                    style: GoogleFonts.oswald(color: Colors.white, fontSize: 16, height: 1.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Huecos de la palabra que se va formando.
          Row(
            children: [
              for (var i = 0; i < word.length; i++)
                Expanded(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WM.outline,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: i < _typed.length ? WM.cyan : Colors.white24, width: 2),
                    ),
                    child: Text(
                      i < _typed.length ? _typed[i] : '',
                      style: GoogleFonts.anton(color: Colors.white, fontSize: 22),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _feedback(_message, _messageGood),
          const Spacer(),
          Row(
            children: [
              for (var i = 0; i < _letters.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _LetterTile(
                      letter: _letters[i],
                      used: _picked.contains(i),
                      onTap: () => _tap(i),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Pressable3D(
                  onTap: () {
                    AudioService.playButtonClick();
                    setState(() {
                      _letters.shuffle(_rnd);
                      _picked.clear();
                    });
                  },
                  color: const Color(0xFF3A2A7A),
                  height: 46,
                  padding: EdgeInsets.zero,
                  child: const Icon(Icons.shuffle_rounded, color: WM.bone),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pressable3D(
                  onTap: _picked.isEmpty ? null : () => setState(() => _picked.removeLast()),
                  color: const Color(0xFF3A2A7A),
                  height: 46,
                  padding: EdgeInsets.zero,
                  child: const Icon(Icons.backspace_rounded, color: WM.bone),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Pressable3D(
                  onTap: _done ? null : _skip,
                  color: const Color(0xFFFF8A3D),
                  height: 46,
                  child: OutlinedGameText(context.l10n.scrambleSkip, size: 17, font: GameFont.oswald),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ¿BIEN ESCRITA?: sale una palabra y hay que decir si está bien o mal
// escrita. 12 palabras, 3 vidas. Si estaba mal, se enseña cómo se escribe
// (así se aprende aunque se falle).
// =====================================================================
class SpellingGame extends StatefulWidget {
  const SpellingGame({super.key, required this.onFinished});
  final ValueChanged<bool> onFinished;

  @override
  State<SpellingGame> createState() => _SpellingGameState();
}

class _SpellingGameState extends State<SpellingGame> {
  static const int totalSeconds = 90;
  static const int rounds = 12;
  static const int maxLives = 3;

  final math.Random _rnd = math.Random();
  List<({String shown, bool isRight, String right})> _items = [];
  int _index = 0;
  int _lives = maxLives;
  int _seconds = totalSeconds;
  Timer? _timer;
  bool _done = false;
  bool _loading = true;

  /// Respuesta del jugador a la palabra actual (null = aún no respondió).
  bool? _answeredOk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _loadData('spelling');
      final all = [for (final i in data['items'] as List) i as Map]..shuffle(_rnd);
      _items = [
        for (final item in all.take(rounds))
          // Mitad de las veces sale bien escrita y mitad mal.
          if (_rnd.nextBool())
            (shown: item['right'] as String, isRight: true, right: item['right'] as String)
          else
            (shown: item['wrong'] as String, isRight: false, right: item['right'] as String),
      ];
    } catch (e) {
      debugPrint('No se pudo cargar ¿Bien escrita?: $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      setState(() => _seconds--);
      if (_seconds <= 0) _finish(false);
    });
  }

  void _answer(bool saysRight) {
    if (_done || _answeredOk != null) return;
    final item = _items[_index];
    final ok = saysRight == item.isRight;
    ok ? AudioService.playSuccess() : AudioService.playWrong();
    setState(() {
      _answeredOk = ok;
      if (!ok) _lives--;
    });
    if (_lives <= 0) {
      _finish(false, delay: 1600);
      return;
    }
    // Si estaba mal escrita, se deja un poco más para leer la corrección.
    Future.delayed(Duration(milliseconds: item.isRight ? 800 : 1500), () {
      if (!mounted || _done) return;
      if (_index + 1 >= _items.length) {
        _finish(true);
      } else {
        setState(() {
          _index++;
          _answeredOk = null;
        });
      }
    });
  }

  void _finish(bool won, {int delay = 400}) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) widget.onFinished(won);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: WM.cyan));
    if (_items.isEmpty) {
      return Center(
        child: Text(context.l10n.tournamentNoQuestions, style: GoogleFonts.oswald(color: Colors.white70)),
      );
    }
    final item = _items[_index];
    final answered = _answeredOk != null;
    final cardColor = !answered
        ? WM.cyan
        : _answeredOk!
            ? WM.green
            : const Color(0xFFFF4D5E);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      child: Column(
        children: [
          _rules(context.l10n.spellingRules(rounds)),
          const SizedBox(height: 8),
          MinigameCountdown(seconds: _seconds, total: totalSeconds),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Chip3D(emoji: '❤️', text: '$_lives', accent: const Color(0xFFFF4D5E), fontSize: 15),
              Chip3D(emoji: '📜', text: '${_index + 1}/$rounds', accent: WM.cyan, fontSize: 15),
            ],
          ),
          const Spacer(),
          // La palabra, en grande.
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
            decoration: BoxDecoration(
              color: WM.outline,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardColor, width: 3),
              boxShadow: [BoxShadow(color: cardColor.withValues(alpha: 0.4), blurRadius: 16)],
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: OutlinedGameText(item.shown, size: 38, letterSpacing: 2),
                ),
                if (answered) ...[
                  const SizedBox(height: 10),
                  Text(
                    _answeredOk! ? context.l10n.spellingYes : context.l10n.spellingNo,
                    style: GoogleFonts.oswald(
                      color: _answeredOk! ? const Color(0xFF9AF2A0) : const Color(0xFFFFB3BA),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Si estaba mal escrita, cómo se escribe de verdad.
                  if (!item.isRight)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        context.l10n.spellingCorrection(item.right),
                        style: GoogleFonts.oswald(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Pressable3D(
                  onTap: answered ? null : () => _answer(false),
                  color: const Color(0xFFFF4D5E),
                  height: 64,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      const SizedBox(width: 6),
                      OutlinedGameText(context.l10n.spellingWrong, size: 20, font: GameFont.oswald),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Pressable3D(
                  onTap: answered ? null : () => _answer(true),
                  color: WM.green,
                  height: 64,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                      const SizedBox(width: 6),
                      OutlinedGameText(context.l10n.spellingRight, size: 20, font: GameFont.oswald),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SERPIENTE DE LETRAS: guiar a la serpiente para que coma las letras EN
// ORDEN y forme las palabras de la lista antes de que acabe el tiempo.
//
// - En el tablero siempre está la letra que toca y dos letras trampa.
// - Letra que toca: la serpiente crece y avanza la palabra.
// - Letra trampa: −3 segundos.
// - Chocar con el borde o con su cola: −5 segundos y vuelve al centro
//   (no se pierde de golpe: es un juego de palabras, no de reflejos).
// - Se maneja deslizando el dedo sobre el tablero o con las flechas.
// =====================================================================
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key, required this.onFinished});
  final ValueChanged<bool> onFinished;

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

typedef _Cell = ({int x, int y});

class _SnakeGameState extends State<SnakeGame> {
  static const int cols = 10;
  static const int rows = 12;
  static const int totalSeconds = 100;
  static const int wordCount = 3;
  static const int decoys = 2;
  static const Duration step = Duration(milliseconds: 280);
  static const _alphabet = 'ABCDEFGHIJKLMNOPRSTUVZ';

  final math.Random _rnd = math.Random();
  List<String> _words = [];
  int _wordIndex = 0;
  int _letterIndex = 0;

  List<_Cell> _snake = [];
  _Cell _dir = (x: 1, y: 0);
  _Cell _nextDir = (x: 1, y: 0);
  int _grow = 0;
  List<({_Cell cell, String letter})> _board = [];

  int _seconds = totalSeconds;
  Timer? _clock;
  Timer? _mover;
  bool _done = false;
  bool _loading = true;
  String? _message;
  bool _messageGood = false;

  String get _word => _words[_wordIndex];
  String get _needed => _word[_letterIndex];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _mover?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _loadData('snake');
      _words = (List<String>.from(data['words'] as List)..shuffle(_rnd)).take(wordCount).toList();
    } catch (e) {
      debugPrint('No se pudo cargar la serpiente de letras: $e');
    }
    if (!mounted) return;
    _resetSnake();
    _spawnLetters();
    setState(() => _loading = false);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      setState(() => _seconds = math.max(0, _seconds - 1));
      if (_seconds <= 0) _finish(false);
    });
    _mover = Timer.periodic(step, (_) => _tick());
  }

  void _resetSnake() {
    const y = rows ~/ 2;
    _snake = [(x: 3, y: y), (x: 2, y: y), (x: 1, y: y)];
    _dir = (x: 1, y: 0);
    _nextDir = _dir;
  }

  bool _onSnake(_Cell c) => _snake.any((s) => s.x == c.x && s.y == c.y);

  _Cell _freeCell() {
    final head = _snake.first;
    for (var tries = 0; tries < 200; tries++) {
      final c = (x: _rnd.nextInt(cols), y: _rnd.nextInt(rows));
      final nearHead = (c.x - head.x).abs() + (c.y - head.y).abs() < 3;
      if (!_onSnake(c) && !nearHead && !_board.any((b) => b.cell == c)) return c;
    }
    return (x: _rnd.nextInt(cols), y: _rnd.nextInt(rows));
  }

  /// Pone en el tablero la letra que toca y las letras trampa.
  void _spawnLetters() {
    _board = [];
    _board.add((cell: _freeCell(), letter: _needed));
    while (_board.length < decoys + 1) {
      final letter = _alphabet[_rnd.nextInt(_alphabet.length)];
      if (letter == _needed) continue;
      _board.add((cell: _freeCell(), letter: letter));
    }
  }

  void _turn(_Cell d) {
    // No se puede dar media vuelta sobre sí misma.
    if (d.x == -_dir.x && d.y == -_dir.y) return;
    _nextDir = d;
  }

  void _tick() {
    if (!mounted || _done || _loading) return;
    _dir = _nextDir;
    final head = _snake.first;
    final next = (x: head.x + _dir.x, y: head.y + _dir.y);
    final hitWall = next.x < 0 || next.y < 0 || next.x >= cols || next.y >= rows;
    // La punta de la cola se mueve en este paso, así que no cuenta.
    final body = _grow > 0 ? _snake : _snake.sublist(0, _snake.length - 1);
    final hitSelf = body.any((s) => s == next);
    if (hitWall || hitSelf) {
      _crash();
      return;
    }
    setState(() {
      _snake.insert(0, next);
      if (_grow > 0) {
        _grow--;
      } else {
        _snake.removeLast();
      }
    });
    final eaten = _board.where((b) => b.cell == next).toList();
    if (eaten.isNotEmpty) _eat(eaten.first);
  }

  void _crash() {
    AudioService.playWrong();
    setState(() {
      _seconds = math.max(0, _seconds - 5);
      _message = context.l10n.snakeCrash;
      _messageGood = false;
      _resetSnake();
      _spawnLetters();
    });
    if (_seconds <= 0) _finish(false);
  }

  void _eat(({_Cell cell, String letter}) item) {
    if (item.letter == _needed) {
      AudioService.playSelect();
      setState(() {
        _grow++;
        _letterIndex++;
        _message = null;
        if (_letterIndex >= _word.length) {
          AudioService.playSuccess();
          _message = context.l10n.forgeGood;
          _messageGood = true;
          _wordIndex++;
          _letterIndex = 0;
        }
      });
      if (_wordIndex >= _words.length) {
        _finish(true);
        return;
      }
      setState(_spawnLetters);
    } else {
      AudioService.playWrong();
      setState(() {
        _seconds = math.max(0, _seconds - 3);
        _message = context.l10n.snakeWrongLetter;
        _messageGood = false;
        // La letra trampa comida aparece en otro sitio.
        _board.remove(item);
        var letter = _alphabet[_rnd.nextInt(_alphabet.length)];
        while (letter == _needed) {
          letter = _alphabet[_rnd.nextInt(_alphabet.length)];
        }
        _board.add((cell: _freeCell(), letter: letter));
      });
      if (_seconds <= 0) _finish(false);
    }
  }

  void _finish(bool won) {
    if (_done) return;
    _done = true;
    _clock?.cancel();
    _mover?.cancel();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) widget.onFinished(won);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: WM.cyan));
    if (_words.isEmpty) {
      return Center(
        child: Text(context.l10n.tournamentNoQuestions, style: GoogleFonts.oswald(color: Colors.white70)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Column(
        children: [
          _rules(context.l10n.snakeRules(wordCount)),
          const SizedBox(height: 6),
          MinigameCountdown(seconds: _seconds, total: totalSeconds),
          const SizedBox(height: 8),
          _buildWordList(),
          const SizedBox(height: 4),
          _feedback(_message, _messageGood),
          const SizedBox(height: 4),
          Expanded(child: _buildBoard()),
          const SizedBox(height: 10),
          _buildPad(),
        ],
      ),
    );
  }

  /// Las palabras: hechas (verdes), la actual (letras comidas resaltadas) y
  /// las que faltan (apagadas).
  Widget _buildWordList() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var w = 0; w < _words.length; w++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: w < _wordIndex ? const Color(0xFF1E8C3A) : WM.outline,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: w < _wordIndex ? WM.green : (w == _wordIndex ? WM.gold : Colors.white24),
                width: w == _wordIndex ? 2 : 1,
              ),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  for (var i = 0; i < _words[w].length; i++)
                    TextSpan(
                      text: _words[w][i],
                      style: GoogleFonts.anton(
                        fontSize: 18,
                        letterSpacing: 2,
                        color: w < _wordIndex
                            ? Colors.white
                            : w == _wordIndex
                                ? (i < _letterIndex ? WM.gold : Colors.white70)
                                : Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, box) {
        final cell = math.min(box.maxWidth / cols, box.maxHeight / rows).floorToDouble();
        final width = cell * cols;
        final height = cell * rows;
        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Deslizar el dedo cambia la dirección.
            onPanEnd: (d) {
              final v = d.velocity.pixelsPerSecond;
              if (v.distance < 80) return;
              _turn(v.dx.abs() > v.dy.abs() ? (x: v.dx.sign.toInt(), y: 0) : (x: 0, y: v.dy.sign.toInt()));
            },
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF14092E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: WM.cyan.withValues(alpha: 0.7), width: 2),
              ),
              child: Stack(
                children: [
                  // Letras del tablero.
                  for (final b in _board)
                    Positioned(
                      left: b.cell.x * cell,
                      top: b.cell.y * cell,
                      width: cell,
                      height: cell,
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: _LetterTile(letter: b.letter, height: cell - 3),
                      ),
                    ),
                  // La serpiente (la cabeza, más clara y con ojos).
                  for (var i = _snake.length - 1; i >= 0; i--)
                    Positioned(
                      left: _snake[i].x * cell,
                      top: _snake[i].y * cell,
                      width: cell,
                      height: cell,
                      child: Padding(
                        padding: EdgeInsets.all(i == 0 ? 0.5 : 2),
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == 0 ? const Color(0xFF7CFF6B) : Color.lerp(const Color(0xFF3BD15A), const Color(0xFF1E8C3A), i / math.max(1, _snake.length)),
                            borderRadius: BorderRadius.circular(cell * (i == 0 ? 0.35 : 0.25)),
                            border: Border.all(color: WM.outline, width: 1.5),
                          ),
                          child: i == 0
                              ? Center(
                                  child: Text('👀', style: TextStyle(fontSize: cell * 0.45)),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Flechas para quien prefiere botones a deslizar.
  Widget _buildPad() {
    Widget arrow(IconData icon, _Cell d) => Expanded(
          child: Pressable3D(
            onTap: () => _turn(d),
            color: const Color(0xFF3A2A7A),
            height: 44,
            padding: EdgeInsets.zero,
            child: Icon(icon, color: WM.bone, size: 26),
          ),
        );
    return Row(
      children: [
        arrow(Icons.arrow_back_rounded, (x: -1, y: 0)),
        const SizedBox(width: 8),
        arrow(Icons.arrow_upward_rounded, (x: 0, y: -1)),
        const SizedBox(width: 8),
        arrow(Icons.arrow_downward_rounded, (x: 0, y: 1)),
        const SizedBox(width: 8),
        arrow(Icons.arrow_forward_rounded, (x: 1, y: 0)),
      ],
    );
  }
}
