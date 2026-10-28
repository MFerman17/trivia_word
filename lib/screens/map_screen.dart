import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/world_map_config.dart';
import '../controllers/map_controller.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import 'game_screen.dart';
import 'mini_challenges_screen.dart';
import '../l10n/l10n.dart';
import '../services/fighter_service.dart';
import '../widgets/game_3d.dart';
import 'fight_screen.dart';
import '../widgets/lives_widgets.dart';
import '../services/chapter_story_service.dart';
import '../services/question_bank.dart';

// Colores coherentes con el estilo del juego
const Color kOutline = Color(0xFF0D0326);
const Color kCyan = Color(0xFF1EE3CF);
const Color kBone = Color(0xFFF4EBDD);
const double kSkew = -0.2;

/// Ponlo en true para calibrar: al tocar el mapa se muestra (y se imprime
/// en consola) la coordenada relativa exacta para pegarla en world_map_config.
const bool kMapEditMode = false;

/// Ancho máximo del mapa (evita que en web/tablet la imagen sea enorme).
const double kMaxMapWidth = 700;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late MapController _controller;
  late AnimationController _pulse;
  late Animation<double> _pulseScale;
  final ScrollController _scroll = ScrollController();

  /// Proporción ancho/alto de cada imagen, leída de la imagen real.
  final Map<String, double> _aspects = {};
  final Set<String> _loadingAspects = {};

  /// Mundo al que ya se hizo scroll automático (para no repetirlo en cada build).
  int? _scrolledWorld;

  bool _isMuted = AudioService.isMuted;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    _controller.loadAllProgress();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    AudioService.playMapMusic();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse.dispose();
    _scroll.dispose();
    // Aquí antes se paraba la música. Como dispose ocurre DESPUÉS de volver
    // a la portada, cortaba la música de la portada recién empezada.
    super.dispose();
  }

  Future<void> _startLevel(int worldId, int chapterId, int levelNumber) async {
    AudioService.playNodeSelect();

    // Sin vidas no se puede jugar: se ofrece recargarlas.
    if (!await ensureLives(context)) return;
    if (!mounted) return;

    // El último nivel de cada capítulo es una pelea: pide estrellas.
    final isFight = FighterService.isFightLevel(levelNumber);
    if (isFight) {
      final missing = FightGate.missingStars(
        chapter: chapterId,
        starsInWorld: _controller.starsInWorld(worldId),
      );
      if (missing > 0) {
        _showFightLocked(chapterId, missing);
        return;
      }
    }

    AudioService.stopBgm(); // El combate pone su propia música al cargar.

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isFight
            ? FightScreen(
                worldId: worldId,
                chapterId: chapterId,
                levelNumber: levelNumber,
              )
            : GameScreen(
                worldId: worldId,
                chapterId: chapterId,
                levelNumber: levelNumber,
              ),
      ),
    ).then((result) async {
      // Al volver, recarga progreso y vuelve a centrar en el nivel actual
      _scrolledWorld = null;
      await _controller.loadAllProgress();
      AudioService.playMapMusic();
      // La pelea final devuelve el número del mundo siguiente: se pasa a él
      // y se cuenta su historia, para que el jugador sepa que ya avanzó.
      if (result is int && mounted) {
        _controller.selectWorld(result);
        _showNewWorld(result);
      }
    });
  }

  /// Presentación del mundo nuevo, con su paisaje y su historia.
  void _showNewWorld(int world) {
    final story = ChapterStoryService.afterChapter(world - 1, 3);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Paisaje del mundo nuevo de fondo, oscurecido.
              Positioned.fill(
                child: Image.asset(
                  QuestionBank.worldBackgroundAsset(world, 1),
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.55),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedGameText(
                      context.l10n.worldButton(world, _worldName(world)).toUpperCase(),
                      size: 26,
                      letterSpacing: 1.5,
                      colors: const [Color(0xFFA8FFF6), kCyan],
                    ),
                    if (story != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        story.heading,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.metalMania(color: WM.gold, fontSize: 21),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story.narrative,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.oswald(color: Colors.white, fontSize: 14, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story.objective,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.oswald(color: kCyan, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Pressable3D(
                        onTap: () {
                          AudioService.playButtonClick();
                          Navigator.of(dialogContext).pop();
                        },
                        color: kCyan,
                        height: 48,
                        child: OutlinedGameText(
                          context.l10n.exploreWorld,
                          size: 17,
                          font: GameFont.oswald,
                        ),
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
    AudioService.playPageFlip();
  }
  /// Aviso cuando aún no hay estrellas suficientes para una pelea.
  void _showFightLocked(int chapter, int missing) {
    final required = FighterService.starsRequired(chapter);
    final isFinal = chapter == 3;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Panel3D(
          accent: isFinal ? const Color(0xFFFF8A3D) : WM.violet,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedGameText(
                isFinal ? context.l10n.finalBattle : context.l10n.guardianFight,
                size: 24,
                letterSpacing: 1.5,
                colors: const [Color(0xFFFFF1B0), WM.gold],
              ),
              const SizedBox(height: 10),
              const Text('🔒', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                context.l10n.starsNeeded(required, missing),
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.starsHowTo,
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
  }


  // =================================================================
  // TAMAÑO REAL DE LAS IMÁGENES
  // =================================================================
  double? _aspectFor(String asset) {
    final aspect = _aspects[asset];
    if (aspect == null && _loadingAspects.add(asset)) {
      _resolveAspect(asset);
    }
    return aspect;
  }

  Future<void> _resolveAspect(String asset) async {
    final completer = Completer<double>();
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(info.image.width / info.image.height);
        }
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!completer.isCompleted) completer.complete(1.0);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    final aspect = await completer.future;
    if (!mounted) return;
    setState(() => _aspects[asset] = aspect);
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final segments =
            kWorldMaps[_controller.selectedWorld] ?? kWorldMaps[1]!;

        return Scaffold(
          backgroundColor: kOutline,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildCustomAppBar(),
                _buildWorldSelector(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _controller.isLoading
                            ? const Center(
                                child: CircularProgressIndicator(color: kCyan))
                            : _buildTrailMap(segments),
                      ),
                      // Vidas globales, flotando sobre el mapa.
                      Positioned(
                        top: 8,
                        left: 12,
                        child: LivesBadge(
                          onTap: () => showOutOfLivesDialogIfEmpty(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =================================================================
  // MAPA: TRAMOS APILADOS (capítulo 1 abajo, capítulo 3 arriba)
  // =================================================================
  Widget _buildTrailMap(List<MapSegment> segments) {
    final aspects = segments.map((s) => _aspectFor(s.asset)).toList();
    if (aspects.any((a) => a == null)) {
      return const Center(child: CircularProgressIndicator(color: kCyan));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, kMaxMapWidth);
        final heights = [for (final a in aspects) width / a!];
        final nodeSize = (width * 0.13).clamp(44.0, 64.0);
        final world = _controller.selectedWorld;
        final currentIndex = _currentLevelIndex(world, segments.length);

        // Tramos de ARRIBA a ABAJO: capítulo 3 parte 2, capítulo 3 parte 1...
        // La parte 2 de cada capítulo es su imagen en espejo (niveles 6-10).
        final parts = <({int chapter, int part})>[
          for (int c = segments.length; c >= 1; c--)
            for (int p = kSegmentsPerChapter - 1; p >= 0; p--) (chapter: c, part: p),
        ];

        _scheduleScrollToCurrent(
          parts,
          segments,
          heights,
          constraints.maxHeight,
          currentIndex,
        );

        return SingleChildScrollView(
          controller: _scroll,
          child: Center(
            child: Column(
              children: [
                for (var i = 0; i < parts.length; i++)
                  _buildSegment(
                    chapter: parts[i].chapter,
                    part: parts[i].part,
                    segment: _segmentFor(segments[parts[i].chapter - 1], parts[i].part),
                    width: width,
                    height: heights[parts[i].chapter - 1],
                    nodeSize: nodeSize,
                    isTop: i == 0,
                    isBottom: i == parts.length - 1,
                    currentIndex: currentIndex,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Índice global (0..14) del último nivel desbloqueado.
  int _currentLevelIndex(int world, int chapters) {
    int current = 0;
    for (int c = 1; c <= chapters; c++) {
      for (int l = 1; l <= kLevelsPerChapter; l++) {
        if (_controller.getProgressForNode(world, c, l).isUnlocked) {
          current = (c - 1) * kLevelsPerChapter + (l - 1);
        }
      }
    }
    return current;
  }

  /// La imagen de un tramo: la parte 0 es la original; la 1, en espejo.
  MapSegment _segmentFor(MapSegment base, int part) => part == 0
      ? base
      : MapSegment(asset: base.asset, nodes: base.nodes, mirrored: !base.mirrored);

  /// Centra la pantalla en el nivel actual al abrir el mundo.
  void _scheduleScrollToCurrent(
    List<({int chapter, int part})> parts,
    List<MapSegment> segments,
    List<double> heights,
    double viewportHeight,
    int currentIndex,
  ) {
    final world = _controller.selectedWorld;
    if (_scrolledWorld == world) return;
    _scrolledWorld = world;

    final chapter = currentIndex ~/ kLevelsPerChapter + 1;
    final inChapter = currentIndex % kLevelsPerChapter;
    final part = inChapter ~/ kNodesPerSegment;
    final node = inChapter % kNodesPerSegment;

    // Suma la altura de los tramos que hay encima del tramo del nivel actual.
    double offset = 0;
    for (final p in parts) {
      if (p.chapter == chapter && p.part == part) break;
      offset += heights[p.chapter - 1];
    }
    final segment = _segmentFor(segments[chapter - 1], part);
    final nodeY = offset + segment.nodeAt(node).dy * heights[chapter - 1];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = (nodeY - viewportHeight / 2)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  // =================================================================
  // UN TRAMO (una imagen + sus 5 niveles)
  // =================================================================
  Widget _buildSegment({
    required int chapter,
    required int part,
    required MapSegment segment,
    required double width,
    required double height,
    required double nodeSize,
    required bool isTop,
    required bool isBottom,
    required int currentIndex,
  }) {
    final world = _controller.selectedWorld;
    // Este tramo se oscurece si su primer nivel aún está bloqueado.
    final chapterLocked = !_controller
        .getProgressForNode(world, chapter, part * kNodesPerSegment + 1)
        .isUnlocked;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Fondo
          Positioned.fill(
            child: Transform.flip(
              flipX: segment.mirrored,
              child: Image.asset(
                segment.asset,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/bg_landscape.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Capítulos bloqueados se ven más oscuros
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black
                    .withValues(alpha: chapterLocked ? 0.4 : 0.1),
              ),
            ),
          ),

          // Niebla que disimula la unión entre tramos
          if (!isTop) _mistBand(atTop: true),
          if (!isBottom) _mistBand(atTop: false),

          // Modo calibración
          if (kMapEditMode)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    _logTap(chapter, segment, d.localPosition, width, height),
              ),
            ),

          // Cartel del capítulo, al inicio (abajo) de su primer tramo
          if (part == 0) _chapterBanner(chapter, chapterLocked),

          // Nodos sobre los círculos del sendero
          for (int i = 0;
              i < segment.nodes.length && i < kNodesPerSegment;
              i++)
            _positionedNode(
              chapter: chapter,
              index: part * kNodesPerSegment + i,
              nodeIndex: i,
              segment: segment,
              width: width,
              height: height,
              nodeSize: nodeSize,
              currentIndex: currentIndex,
            ),
        ],
      ),
    );
  }

  Widget _positionedNode({
    required int chapter,
    required int index, // nivel dentro del capítulo (0..9)
    required int nodeIndex, // plataforma dentro de la imagen (0..4)
    required MapSegment segment,
    required double width,
    required double height,
    required double nodeSize,
    required int currentIndex,
  }) {
    final pos = segment.nodeAt(nodeIndex);
    final progress = _controller.getProgressForNode(
      _controller.selectedWorld,
      chapter,
      index + 1,
    );
    final globalIndex = (chapter - 1) * kLevelsPerChapter + index;

    return Positioned(
      left: pos.dx * width - nodeSize / 2,
      top: pos.dy * height - nodeSize / 2,
      width: nodeSize,
      child: _buildPathNode(
        progress,
        globalIndex + 1,
        nodeSize: nodeSize,
        isCurrent: globalIndex == currentIndex && progress.stars == 0,
      ),
    );
  }

  Widget _mistBand({required bool atTop}) {
    return Positioned(
      left: 0,
      right: 0,
      top: atTop ? 0 : null,
      bottom: atTop ? null : 0,
      height: 90,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                kOutline.withValues(alpha: 0.95),
                kOutline.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chapterBanner(int chapter, bool locked) {
    final color = locked ? Colors.white38 : kCyan;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 14,
      child: IgnorePointer(
        child: Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(kSkew),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
              decoration: BoxDecoration(
                color: kOutline,
                border: Border.all(color: color, width: 2),
              ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(-kSkew),
                child: Text(
                  context.l10n.chapterLabel(chapter),
                  style: GoogleFonts.metalMania(
                    color: color,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _logTap(
    int chapter,
    MapSegment segment,
    Offset local,
    double width,
    double height,
  ) {
    var dx = local.dx / width;
    final dy = local.dy / height;
    if (segment.mirrored) dx = 1 - dx; // se guarda en coordenadas sin espejo
    final text =
        'Offset(${dx.toStringAsFixed(2)}, ${dy.toStringAsFixed(2)})';
    debugPrint('Mundo ${_controller.selectedWorld} · Capítulo $chapter → $text');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  // =================================================================
  // APPBAR PERSONALIZADA
  // =================================================================
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: kOutline.withValues(alpha: 0.9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                context.l10n.worldLabel(_controller.selectedWorld),
                style: GoogleFonts.anton(
                  color: kCyan,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: context.l10n.worldChallengesTooltip,
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE783), Color(0xFFEF8C20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withValues(alpha: 0.65),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFF3B1B36),
                    size: 24,
                  ),
                ),
                onPressed: () {
                  if (!_controller.isWorldUnlocked(
                    _controller.selectedWorld,
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.worldLocked,
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MiniChallengesScreen(
                        worldId: _controller.selectedWorld,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  _isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: _isMuted ? Colors.redAccent : Colors.amberAccent,
                  size: 24,
                ),
                onPressed: () {
                  AudioService.toggleMute();
                  setState(() {
                    _isMuted = AudioService.isMuted;
                  });
                },
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      '${_controller.totalStars}',
                      style: GoogleFonts.oswald(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =================================================================
  // SELECTOR DE MUNDOS HORIZONTAL
  // =================================================================
  /// Nombre de cada mundo en el idioma actual.
  String _worldName(int world) => switch (world) {
        1 => context.l10n.worldName1,
        2 => context.l10n.worldName2,
        3 => context.l10n.worldName3,
        _ => context.l10n.worldName4,
      };

  Widget _buildWorldSelector() {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black.withValues(alpha: 0.4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: kWorldMaps.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final worldNum = index + 1;
          final isSelected = worldNum == _controller.selectedWorld;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: InkWell(
              onTap: () => _controller.selectWorld(worldNum),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF00FFA3), Color(0xFF00B8FF)])
                      : LinearGradient(colors: [
                          const Color(0xFF2B2B48),
                          Colors.black.withValues(alpha: 0.6)
                        ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white24,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    // Cada mundo con el nombre de su historia: "1 · BOSQUE".
                    context.l10n
                        .worldButton(worldNum, _worldName(worldNum))
                        .toUpperCase(),
                    style: GoogleFonts.anton(
                      color: isSelected ? kOutline : Colors.white70,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =================================================================
  // NODO INDIVIDUAL DE NIVEL
  // =================================================================
  Widget _buildPathNode(
    StageProgress progress,
    int number, {
    required double nodeSize,
    required bool isCurrent,
  }) {
    final unlocked = progress.isUnlocked;
    final completed = progress.stars > 0;

    Widget circle = Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? null : kOutline.withValues(alpha: 0.7),
        gradient: !unlocked
            ? null
            : completed
                ? const RadialGradient(
                    colors: [Color(0xFF1B1140), kOutline])
                : const RadialGradient(
                    colors: [kCyan, Color(0xFF0A8F85)]),
        border: Border.all(
          color: !unlocked
              ? Colors.white24
              : completed
                  ? kCyan
                  : kBone,
          width: 3,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: kCyan.withValues(alpha: completed ? 0.35 : 0.6),
                  blurRadius: completed ? 10 : 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: unlocked
            ? FighterService.isFightLevel(progress.levelNumber)
                // Pelea: espadas (guardián) o corona (batalla final).
                ? Text(
                    progress.chapterId == 3 ? '👑' : '⚔️',
                    style: TextStyle(fontSize: nodeSize * 0.4),
                  )
                : Text(
                    '$number',
                    style: GoogleFonts.anton(
                      color: completed ? kCyan : kOutline,
                      fontSize: nodeSize * 0.38,
                    ),
                  )
            : Icon(Icons.lock_rounded,
                color: Colors.white38, size: nodeSize * 0.4),
      ),
    );

    // Solo el nivel actual "late", para guiar la vista del jugador
    if (isCurrent) {
      circle = ScaleTransition(scale: _pulseScale, child: circle);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: unlocked
              ? () => _startLevel(
                    progress.worldId,
                    progress.chapterId,
                    progress.levelNumber,
                  )
              : null,
          child: circle,
        ),
        if (unlocked && FighterService.isFightLevel(progress.levelNumber) && progress.stars == 0)
          _fightRequirementBadge(progress),
        if (unlocked) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (starIndex) {
              final earned = starIndex < progress.stars;
              return Icon(
                earned ? Icons.star_rounded : Icons.star_border_rounded,
                size: 15,
                color: earned ? Colors.amberAccent : Colors.white38,
              );
            }),
          ),
        ],
      ],
    );
  }

  /// Etiqueta "★ 6/8" bajo una pelea que aún no se ha ganado.
  Widget _fightRequirementBadge(StageProgress progress) {
    final have = _controller.starsInWorld(progress.worldId);
    final need = FighterService.starsRequired(progress.chapterId);
    final ok = have >= need;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: kOutline.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? const Color(0xFF5BE37A) : Colors.white38, width: 1.5),
      ),
      child: Text(
        '★ ${have > need ? need : have}/$need',
        style: GoogleFonts.oswald(
          color: ok ? const Color(0xFF9AF2A0) : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
