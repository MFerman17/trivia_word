import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/locale_service.dart';
import '../services/minigame_service.dart';
import '../widgets/game_3d.dart';

/// Pantalla de un portal: juega el minijuego y, al terminar, entrega el
/// premio y vuelve al mapa (devuelve true si se jugó).
class MinigameScreen extends StatefulWidget {
  const MinigameScreen({
    super.key,
    required this.world,
    required this.chapter,
    required this.level,
  });

  final int world;
  final int chapter;
  final int level;

  @override
  State<MinigameScreen> createState() => _MinigameScreenState();
}

class _MinigameScreenState extends State<MinigameScreen> {
  late final MinigameType _type =
      MinigameService.typeFor(widget.world, widget.chapter, widget.level);
  bool _finished = false;

  Future<void> _onFinished(bool won) async {
    if (_finished) return;
    _finished = true;
    won ? AudioService.playVictorySound() : AudioService.playDefeatSound();
    final reward = await MinigameService.finish(
      world: widget.world,
      chapter: widget.chapter,
      level: widget.level,
      won: won,
    );
    if (!mounted) return;
    AudioService.playCoins();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: Panel3D(
          accent: won ? WM.gold : WM.violet,
          glow: won ? 0.8 : 0,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(won ? '🏆' : '🙂', style: const TextStyle(fontSize: 46)),
              const SizedBox(height: 6),
              OutlinedGameText(
                won ? context.l10n.minigameWon : context.l10n.minigameLost,
                size: 24,
                colors: const [Color(0xFFFFF1B0), WM.gold],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  Chip3D(emoji: '🪙', text: '+${reward.coins}', accent: WM.gold, fontSize: 15),
                  if (reward.gems > 0)
                    Chip3D(emoji: '💎', text: '+${reward.gems}', accent: WM.cyan, fontSize: 15),
                  if (reward.hints > 0)
                    Chip3D(emoji: '💡', text: '+${reward.hints}', accent: WM.gold, fontSize: 15),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.minigameComeBack,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(color: Colors.white60, fontSize: 13),
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
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_type) {
      MinigameType.memory => context.l10n.minigameMemory,
      MinigameType.hangman => context.l10n.minigameHangman,
      MinigameType.wordSearch => context.l10n.minigameWordSearch,
      MinigameType.wordForge => context.l10n.minigameWordForge,
    };
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: title),
              Expanded(
                child: switch (_type) {
                  MinigameType.memory => _MemoryGame(onFinished: _onFinished),
                  MinigameType.hangman => _HangmanGame(onFinished: _onFinished),
                  MinigameType.wordSearch => _WordSearchGame(onFinished: _onFinished),
                  MinigameType.wordForge => _WordForgeGame(onFinished: _onFinished),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// MEMORIA: encontrar las 6 parejas antes de quedarse sin intentos
// =====================================================================
class _MemoryGame extends StatefulWidget {
  const _MemoryGame({required this.onFinished});
  final ValueChanged<bool> onFinished;

  @override
  State<_MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<_MemoryGame> {
  static const List<String> _pool = [
    '🐉', '🦉', '🧚', '🧭', '📖', '🔥', '💎', '🗝️', '🧪', '🛡️', '🍄', '🌙',
  ];
  static const int _pairs = 6;

  /// Intentos (parejas destapadas) permitidos antes de perder.
  static const int maxTries = 14;

  late final List<String> _cards;
  final Set<int> _matched = {};
  final List<int> _open = [];
  int _tries = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    final picked = (List<String>.of(_pool)..shuffle(rnd)).take(_pairs).toList();
    _cards = [...picked, ...picked]..shuffle(rnd);
  }

  void _tap(int index) {
    if (_busy || _matched.contains(index) || _open.contains(index)) return;
    AudioService.playSelect();
    setState(() => _open.add(index));
    if (_open.length < 2) return;

    _tries++;
    final a = _open[0], b = _open[1];
    if (_cards[a] == _cards[b]) {
      AudioService.playSuccess();
      setState(() {
        _matched..add(a)..add(b);
        _open.clear();
      });
      if (_matched.length == _cards.length) widget.onFinished(true);
    } else {
      _busy = true;
      Future.delayed(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          _open.clear();
          _busy = false;
        });
        if (_tries >= maxTries) widget.onFinished(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = maxTries - _tries;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          Text(
            context.l10n.memoryRules,
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Chip3D(
            emoji: '🔁',
            text: context.l10n.triesLeft(left),
            accent: left <= 3 ? const Color(0xFFFF5A6E) : WM.cyan,
            fontSize: 14,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < _cards.length; i++) _buildCard(i),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(int i) {
    final visible = _open.contains(i) || _matched.contains(i);
    final matched = _matched.contains(i);
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: visible
                ? [const Color(0xFF3A2A7A), WM.panelBottom]
                : [WM.violet, const Color(0xFF3A2A7A)],
          ),
          border: Border.all(
            color: matched ? WM.gold : (visible ? WM.cyan : WM.outline),
            width: 3,
          ),
          boxShadow: matched
              ? [BoxShadow(color: WM.gold.withValues(alpha: 0.5), blurRadius: 10)]
              : const [BoxShadow(color: WM.outline, offset: Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            visible ? _cards[i] : '❔',
            style: TextStyle(fontSize: visible ? 34 : 26),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// AHORCADO: adivinar la palabra antes de 6 fallos
// =====================================================================
class _HangmanGame extends StatefulWidget {
  const _HangmanGame({required this.onFinished});
  final ValueChanged<bool> onFinished;

  @override
  State<_HangmanGame> createState() => _HangmanGameState();
}

class _HangmanGameState extends State<_HangmanGame> {
  static const int maxMistakes = 6;

  // Palabras del mundo del juego, sin tildes para que el teclado sea simple.
  static const List<String> _wordsEs = [
    'DRAGON', 'CASTILLO', 'BOSQUE', 'VOLCAN', 'CAVERNA', 'TESORO', 'ESPADA',
    'ESCUDO', 'POCION', 'BRUJULA', 'HECHIZO', 'GUARDIAN', 'MONSTRUO', 'CORONA',
    'LEYENDA', 'AVENTURA', 'MONTAÑA', 'CASCADA', 'RELAMPAGO', 'ARCOIRIS',
    'BIBLIOTECA', 'DICCIONARIO', 'PALABRA', 'MAGIA', 'FENIX', 'LECHUZA',
    'ESTRELLA', 'COFRE', 'MAPA', 'SENDERO', 'PUENTE', 'ISLA', 'NUBE', 'LAVA',
    'CRISTAL', 'GIGANTE', 'HADA', 'DUENDE', 'ANTORCHA', 'PERGAMINO',
  ];
  static const List<String> _wordsEn = [
    'DRAGON', 'CASTLE', 'FOREST', 'VOLCANO', 'CAVERN', 'TREASURE', 'SWORD',
    'SHIELD', 'POTION', 'COMPASS', 'SPELL', 'GUARDIAN', 'MONSTER', 'CROWN',
    'LEGEND', 'ADVENTURE', 'MOUNTAIN', 'WATERFALL', 'LIGHTNING', 'RAINBOW',
    'LIBRARY', 'DICTIONARY', 'WORD', 'MAGIC', 'PHOENIX', 'OWL', 'STAR',
    'CHEST', 'MAP', 'PATH', 'BRIDGE', 'ISLAND', 'CLOUD', 'LAVA', 'CRYSTAL',
    'GIANT', 'FAIRY', 'GOBLIN', 'TORCH', 'SCROLL',
  ];

  late final bool _spanish = LocaleService.languageCode == 'es';
  late final String _word;
  final Set<String> _guessed = {};
  int _mistakes = 0;
  bool _done = false;

  List<String> get _keyboard => [
        ...'ABCDEFGHIJKLMN'.split(''),
        if (_spanish) 'Ñ',
        ...'OPQRSTUVWXYZ'.split(''),
      ];

  @override
  void initState() {
    super.initState();
    final words = _spanish ? _wordsEs : _wordsEn;
    _word = words[math.Random().nextInt(words.length)];
  }

  bool get _solved => _word.split('').every(_guessed.contains);

  void _guess(String letter) {
    if (_done || _guessed.contains(letter)) return;
    setState(() {
      _guessed.add(letter);
      if (!_word.contains(letter)) _mistakes++;
    });
    if (_word.contains(letter)) {
      AudioService.playSuccess();
    } else {
      AudioService.playWrong();
    }
    if (_solved) {
      _done = true;
      widget.onFinished(true);
    } else if (_mistakes >= maxMistakes) {
      _done = true;
      setState(() => _guessed.addAll(_word.split(''))); // enseña la palabra
      Future.delayed(const Duration(milliseconds: 900), () => widget.onFinished(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    // En vez del muñeco clásico, el dragón que se acerca con cada fallo.
    final danger = _mistakes / maxMistakes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      child: Column(
        children: [
          Text(
            context.l10n.hangmanRules,
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < maxMistakes; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    i < maxMistakes - _mistakes ? '❤️' : '🖤',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // El dragón crece (se acerca) con cada fallo y se pone rojo al final.
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            height: 110 + danger * 70,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Color.lerp(Colors.transparent, const Color(0x88FF2A2A), danger)!,
                BlendMode.srcATop,
              ),
              child: Image.asset(
                'assets/images/dragon.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('🐉', style: TextStyle(fontSize: 64)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final letter in _word.split(''))
                Container(
                  width: 30,
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: WM.cyan, width: 3)),
                  ),
                  child: Center(
                    child: OutlinedGameText(
                      _guessed.contains(letter) ? letter : ' ',
                      size: 24,
                      colors: _mistakes >= maxMistakes && _guessed.contains(letter)
                          ? const [Color(0xFFFFB3BA), Color(0xFFFF5A6E)]
                          : const [Colors.white, WM.bone],
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final letter in _keyboard) _key(letter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(String letter) {
    final used = _guessed.contains(letter);
    final good = used && _word.contains(letter);
    return SizedBox(
      width: 38,
      child: Pressable3D(
        onTap: used || _done ? null : () => _guess(letter),
        color: WM.violet,
        disabledColor: good ? const Color(0xFF1E8C3A) : const Color(0xFF3A3550),
        height: 42,
        depth: 4,
        radius: 8,
        padding: EdgeInsets.zero,
        child: OutlinedGameText(letter, size: 17, font: GameFont.oswald),
      ),
    );
  }
}

// =====================================================================
// Reloj compartido por los juegos con tiempo
// =====================================================================
class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds, required this.total});
  final int seconds;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = (seconds / total).clamp(0.0, 1.0);
    final color = value > 0.5
        ? WM.cyan
        : value > 0.2
            ? WM.gold
            : const Color(0xFFFF5A6E);
    return Row(
      children: [
        const Text('⏳', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: WM.outline,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedGameText('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            size: 15, font: GameFont.oswald),
      ],
    );
  }
}

// =====================================================================
// SOPA DE LETRAS: encontrar las 6 palabras del tema arrastrando el dedo
// =====================================================================
class _WordSearchGame extends StatefulWidget {
  const _WordSearchGame({required this.onFinished});
  final ValueChanged<bool> onFinished;

  @override
  State<_WordSearchGame> createState() => _WordSearchGameState();
}

class _WordSearchGameState extends State<_WordSearchGame> {
  static const int size = 9;
  static const int wordsPerGame = 6;
  static const int totalSeconds = 150;

  // Temas con palabras del mundo del juego (sin tildes, máx. 8 letras).
  static const Map<String, List<String>> _themesEs = {
    'FANTASÍA': ['DRAGON', 'CASTILLO', 'ESPADA', 'ESCUDO', 'MAGIA', 'HADA', 'DUENDE', 'TESORO', 'CORONA', 'POCION', 'HECHIZO', 'GIGANTE'],
    'ANIMALES': ['LEON', 'TIGRE', 'CEBRA', 'JIRAFA', 'BALLENA', 'DELFIN', 'AGUILA', 'LOBO', 'CONEJO', 'TORTUGA', 'PANDA', 'CABALLO'],
    'NATURALEZA': ['BOSQUE', 'VOLCAN', 'MONTAÑA', 'RIO', 'CASCADA', 'ISLA', 'DESIERTO', 'SELVA', 'LAGO', 'NUBE', 'ARBOL', 'FLOR'],
    'ESPACIO': ['ESTRELLA', 'PLANETA', 'LUNA', 'SOL', 'COMETA', 'COHETE', 'GALAXIA', 'ORBITA', 'MARTE', 'NEBULOSA', 'ASTRO', 'SATURNO'],
    'COMIDA': ['MANZANA', 'QUESO', 'PAN', 'SOPA', 'ARROZ', 'PERA', 'UVA', 'TOMATE', 'GALLETA', 'MIEL', 'HUEVO', 'PASTEL'],
    'ESCUELA': ['LIBRO', 'LAPIZ', 'MAPA', 'REGLA', 'PIZARRA', 'CUADERNO', 'CLASE', 'EXAMEN', 'PALABRA', 'LETRA', 'NUMERO', 'GOMA'],
  };
  static const Map<String, List<String>> _themesEn = {
    'FANTASY': ['DRAGON', 'CASTLE', 'SWORD', 'SHIELD', 'MAGIC', 'FAIRY', 'GOBLIN', 'TREASURE', 'CROWN', 'POTION', 'SPELL', 'GIANT'],
    'ANIMALS': ['LION', 'TIGER', 'ZEBRA', 'GIRAFFE', 'WHALE', 'DOLPHIN', 'EAGLE', 'WOLF', 'RABBIT', 'TURTLE', 'PANDA', 'HORSE'],
    'NATURE': ['FOREST', 'VOLCANO', 'MOUNTAIN', 'RIVER', 'ISLAND', 'DESERT', 'JUNGLE', 'LAKE', 'CLOUD', 'TREE', 'FLOWER', 'OCEAN'],
    'SPACE': ['STAR', 'PLANET', 'MOON', 'SUN', 'COMET', 'ROCKET', 'GALAXY', 'ORBIT', 'MARS', 'NEBULA', 'SATURN', 'ASTEROID'],
    'FOOD': ['APPLE', 'CHEESE', 'BREAD', 'SOUP', 'RICE', 'PEAR', 'GRAPE', 'TOMATO', 'COOKIE', 'HONEY', 'EGG', 'CAKE'],
    'SCHOOL': ['BOOK', 'PENCIL', 'MAP', 'RULER', 'BOARD', 'NOTEBOOK', 'CLASS', 'EXAM', 'WORD', 'LETTER', 'NUMBER', 'ERASER'],
  };

  static const List<math.Point<int>> _directions = [
    math.Point(1, 0), math.Point(0, 1), math.Point(1, 1), math.Point(1, -1), // derecha, abajo, diagonales
    math.Point(-1, 0), math.Point(0, -1), // al revés (más difícil)
  ];

  final math.Random _rnd = math.Random();
  late final String _theme;
  late final List<List<String>> _grid;
  final List<String> _words = [];
  final Map<String, List<math.Point<int>>> _placed = {};
  final Set<String> _found = {};
  final Set<math.Point<int>> _foundCells = {};
  math.Point<int>? _dragStart;
  List<math.Point<int>> _selection = [];
  int _seconds = totalSeconds;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final themes = LocaleService.languageCode == 'en' ? _themesEn : _themesEs;
    _theme = themes.keys.elementAt(_rnd.nextInt(themes.length));
    _build(themes[_theme]!);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      setState(() => _seconds--);
      if (_seconds <= 0) {
        _done = true;
        widget.onFinished(false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Coloca las palabras en la cuadrícula y rellena el resto con letras.
  void _build(List<String> pool) {
    _grid = List.generate(size, (_) => List.filled(size, ''));
    final candidates = List<String>.of(pool)..shuffle(_rnd);
    for (final word in candidates) {
      if (_words.length >= wordsPerGame) break;
      if (word.length > size) continue;
      for (var tries = 0; tries < 80; tries++) {
        final dir = _directions[_rnd.nextInt(_directions.length)];
        final x = _rnd.nextInt(size), y = _rnd.nextInt(size);
        final cells = [for (var i = 0; i < word.length; i++) math.Point(x + dir.x * i, y + dir.y * i)];
        final fits = cells.every((c) => c.x >= 0 && c.y >= 0 && c.x < size && c.y < size) &&
            [for (var i = 0; i < word.length; i++) i].every((i) {
              final current = _grid[cells[i].y][cells[i].x];
              return current.isEmpty || current == word[i];
            });
        if (!fits) continue;
        for (var i = 0; i < word.length; i++) {
          _grid[cells[i].y][cells[i].x] = word[i];
        }
        _words.add(word);
        _placed[word] = cells;
        break;
      }
    }
    const letters = 'ABCDEFGHIJKLMNOPRSTUVZ';
    for (final row in _grid) {
      for (var x = 0; x < size; x++) {
        if (row[x].isEmpty) row[x] = letters[_rnd.nextInt(letters.length)];
      }
    }
  }

  math.Point<int>? _cellAt(Offset local, double cell) {
    final x = (local.dx / cell).floor(), y = (local.dy / cell).floor();
    if (x < 0 || y < 0 || x >= size || y >= size) return null;
    return math.Point(x, y);
  }

  /// Línea recta (horizontal, vertical o diagonal) entre dos casillas.
  List<math.Point<int>> _line(math.Point<int> a, math.Point<int> b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    if (!(dx == 0 || dy == 0 || dx.abs() == dy.abs())) return _selection;
    final steps = math.max(dx.abs(), dy.abs());
    final sx = dx.sign, sy = dy.sign;
    return [for (var i = 0; i <= steps; i++) math.Point(a.x + sx * i, a.y + sy * i)];
  }

  void _endDrag() {
    final text = _selection.map((c) => _grid[c.y][c.x]).join();
    final reversed = text.split('').reversed.join();
    final word = _words.firstWhere(
      (w) => !_found.contains(w) && (w == text || w == reversed),
      orElse: () => '',
    );
    setState(() {
      if (word.isNotEmpty) {
        _found.add(word);
        _foundCells.addAll(_selection);
      }
      _selection = [];
      _dragStart = null;
    });
    if (word.isNotEmpty) {
      AudioService.playSuccess();
      if (_found.length == _words.length && !_done) {
        _done = true;
        widget.onFinished(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      child: Column(
        children: [
          Text(
            context.l10n.wordSearchRules,
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          OutlinedGameText(_theme, size: 20, colors: const [Color(0xFFFFF1B0), WM.gold]),
          const SizedBox(height: 6),
          _Countdown(seconds: _seconds, total: totalSeconds),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cell = constraints.maxWidth / size;
                    return GestureDetector(
                      onPanStart: (d) {
                        final c = _cellAt(d.localPosition, cell);
                        if (c == null || _done) return;
                        setState(() {
                          _dragStart = c;
                          _selection = [c];
                        });
                      },
                      onPanUpdate: (d) {
                        final start = _dragStart;
                        final c = _cellAt(d.localPosition, cell);
                        if (start == null || c == null) return;
                        setState(() => _selection = _line(start, c));
                      },
                      onPanEnd: (_) => _endDrag(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: WM.panelBottom,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: WM.cyan, width: 2),
                        ),
                        child: Column(
                          children: [
                            for (var y = 0; y < size; y++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (var x = 0; x < size; x++) _cell(math.Point(x, y), cell),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in _words)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _found.contains(w) ? const Color(0xFF1E8C3A) : WM.outline,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _found.contains(w) ? WM.green : Colors.white24),
                  ),
                  child: Text(
                    w,
                    style: GoogleFonts.oswald(
                      color: _found.contains(w) ? Colors.white60 : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: _found.contains(w) ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(math.Point<int> c, double cell) {
    final selected = _selection.contains(c);
    final found = _foundCells.contains(c);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: selected
              ? WM.gold
              : found
                  ? const Color(0xFF2FA84A)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(cell / 3),
        ),
        alignment: Alignment.center,
        child: Text(
          _grid[c.y][c.x],
          style: GoogleFonts.anton(
            color: selected ? WM.outline : Colors.white,
            fontSize: cell * 0.5,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// FORJA DE PALABRAS (tipo Scrabble): formar palabras con las letras
// =====================================================================
class _WordForgeGame extends StatefulWidget {
  const _WordForgeGame({required this.onFinished});
  final ValueChanged<bool> onFinished;

  @override
  State<_WordForgeGame> createState() => _WordForgeGameState();
}

class _WordForgeGameState extends State<_WordForgeGame> {
  static const int totalSeconds = 150;
  static const int maxGoal = 6;

  final math.Random _rnd = math.Random();
  List<String> _letters = [];
  List<String> _words = [];
  final List<int> _picked = []; // posiciones de las letras usadas
  final Set<String> _found = {};
  String? _message;
  bool _messageGood = false;
  int _seconds = totalSeconds;
  Timer? _timer;
  bool _done = false;
  bool _loading = true;

  int get _goal => math.min(maxGoal, _words.length);

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

  /// Carga un rompecabezas al azar del idioma del jugador.
  Future<void> _load() async {
    final lang = LocaleService.languageCode == 'en' ? 'en' : 'es';
    try {
      final raw = await rootBundle.loadString('assets/minigames/forge_$lang.json');
      final puzzles = (jsonDecode(raw) as Map<String, dynamic>)['puzzles'] as List;
      final puzzle = puzzles[_rnd.nextInt(puzzles.length)] as Map<String, dynamic>;
      _letters = (puzzle['letters'] as String).split('')..shuffle(_rnd);
      _words = List<String>.from(puzzle['words'] as List);
    } catch (e) {
      debugPrint('No se pudo cargar la forja de palabras: $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      setState(() => _seconds--);
      if (_seconds <= 0) {
        _done = true;
        widget.onFinished(false);
      }
    });
  }

  String get _current => _picked.map((i) => _letters[i]).join();

  void _tapLetter(int i) {
    if (_done || _picked.contains(i)) return;
    AudioService.playSelect();
    setState(() {
      _picked.add(i);
      _message = null;
    });
  }

  void _backspace() {
    if (_picked.isEmpty) return;
    setState(() => _picked.removeLast());
  }

  void _shuffle() {
    AudioService.playButtonClick();
    setState(() {
      _picked.clear();
      _letters.shuffle(_rnd);
    });
  }

  void _submit() {
    final word = _current;
    if (word.length < 3 || _done) return;
    setState(() {
      if (_found.contains(word)) {
        _message = context.l10n.forgeAlreadyFound;
        _messageGood = false;
        AudioService.playWrong();
      } else if (_words.contains(word)) {
        _found.add(word);
        // La palabra que usa TODAS las letras es la "palabra maestra".
        _message = word.length == _letters.length
            ? context.l10n.forgeMasterWord
            : context.l10n.forgeGood;
        _messageGood = true;
        AudioService.playSuccess();
      } else {
        _message = context.l10n.forgeNotValid;
        _messageGood = false;
        AudioService.playWrong();
      }
      _picked.clear();
    });
    if (_found.length >= _goal && !_done) {
      _done = true;
      Future.delayed(const Duration(milliseconds: 600), () => widget.onFinished(true));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: WM.cyan));
    if (_words.isEmpty) {
      return Center(
        child: Text(context.l10n.tournamentNoQuestions,
            style: GoogleFonts.oswald(color: Colors.white70)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      child: Column(
        children: [
          Text(
            context.l10n.forgeRules(_goal),
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _Countdown(seconds: _seconds, total: totalSeconds),
          const SizedBox(height: 8),
          Chip3D(
            emoji: '🔨',
            text: '${_found.length}/$_goal',
            accent: _found.length >= _goal ? WM.green : WM.gold,
            fontSize: 15,
          ),
          const SizedBox(height: 10),
          // Las palabras escondidas, como huecos que se van llenando.
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [for (final w in _words) _slot(w)],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: _message == null
                ? null
                : Text(
                    _message!,
                    style: GoogleFonts.oswald(
                      color: _messageGood ? const Color(0xFF9AF2A0) : const Color(0xFFFFB3BA),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          // La palabra que se está formando.
          Container(
            height: 48,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WM.outline,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WM.cyan, width: 2),
            ),
            child: OutlinedGameText(_current.isEmpty ? '·' : _current, size: 26, letterSpacing: 4),
          ),
          const SizedBox(height: 12),
          // Fichas de letras, como las de Scrabble.
          // Cada ficha ocupa la misma parte del ancho: caben 7 en cualquier móvil.
          Row(
            children: [
              for (var i = 0; i < _letters.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _tile(i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Pressable3D(
                  onTap: _shuffle,
                  color: const Color(0xFF3A2A7A),
                  height: 46,
                  padding: EdgeInsets.zero,
                  child: const Icon(Icons.shuffle_rounded, color: WM.bone),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pressable3D(
                  onTap: _picked.isEmpty ? null : _backspace,
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
                  onTap: _current.length >= 3 ? _submit : null,
                  color: WM.gold,
                  height: 46,
                  child: OutlinedGameText(context.l10n.forgeCheck, size: 17, font: GameFont.oswald),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slot(String word) {
    final found = _found.contains(word);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: found ? const Color(0xFF1E8C3A) : WM.outline,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: found ? WM.green : Colors.white24),
      ),
      child: Text(
        found ? word : List.filled(word.length, '_').join(' '),
        style: GoogleFonts.oswald(
          color: found ? Colors.white : Colors.white54,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: found ? 1.5 : 0,
        ),
      ),
    );
  }

  Widget _tile(int i) {
    final used = _picked.contains(i);
    return GestureDetector(
      onTap: () => _tapLetter(i),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: used ? 0.3 : 1,
        child: Container(
          height: 50,
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
          child: Text(
            _letters[i],
            style: GoogleFonts.anton(color: WM.outline, fontSize: 24),
          ),
        ),
      ),
    );
  }
}
