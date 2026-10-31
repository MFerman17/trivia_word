import 'dart:math' as math;

import 'package:flutter/material.dart';
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
