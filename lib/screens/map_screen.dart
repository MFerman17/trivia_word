import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/world_map_config.dart';
import '../controllers/map_controller.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import 'game_screen.dart';

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

    AudioService.playBgm('game_bgm.mp3');
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse.dispose();
    _scroll.dispose();
    AudioService.stopBgm();
    super.dispose();
  }

  void _startLevel(int worldId, int chapterId, int levelNumber) {
    AudioService.stopBgm();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          worldId: worldId,
          chapterId: chapterId,
          levelNumber: levelNumber,
        ),
      ),
    ).then((_) {
      // Al volver, recarga progreso y vuelve a centrar en el nivel actual
      _scrolledWorld = null;
      _controller.loadAllProgress();
      AudioService.playBgm('game_bgm.mp3');
    });
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
                  child: _controller.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kCyan))
                      : _buildTrailMap(segments),
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

        _scheduleScrollToCurrent(
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
                for (int c = segments.length; c >= 1; c--)
                  _buildSegment(
                    chapter: c,
                    segment: segments[c - 1],
                    width: width,
                    height: heights[c - 1],
                    nodeSize: nodeSize,
                    isTop: c == segments.length,
                    isBottom: c == 1,
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

  /// Centra la pantalla en el nivel actual al abrir el mundo.
  void _scheduleScrollToCurrent(
    List<MapSegment> segments,
    List<double> heights,
    double viewportHeight,
    int currentIndex,
  ) {
    final world = _controller.selectedWorld;
    if (_scrolledWorld == world) return;
    _scrolledWorld = world;

    final chapter = currentIndex ~/ kLevelsPerChapter + 1;
    final i = currentIndex % kLevelsPerChapter;

    double offset = 0;
    for (int c = segments.length; c > chapter; c--) {
      offset += heights[c - 1];
    }
    final nodeY =
        offset + segments[chapter - 1].nodeAt(i).dy * heights[chapter - 1];

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
    required MapSegment segment,
    required double width,
    required double height,
    required double nodeSize,
    required bool isTop,
    required bool isBottom,
    required int currentIndex,
  }) {
    final world = _controller.selectedWorld;
    final chapterLocked =
        !_controller.getProgressForNode(world, chapter, 1).isUnlocked;

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

          // Cartel del capítulo, al inicio (abajo) de cada tramo
          _chapterBanner(chapter, chapterLocked),

          // Nodos sobre los círculos del sendero
          for (int i = 0;
              i < segment.nodes.length && i < kLevelsPerChapter;
              i++)
            _positionedNode(
              chapter: chapter,
              index: i,
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
    required int index,
    required MapSegment segment,
    required double width,
    required double height,
    required double nodeSize,
    required int currentIndex,
  }) {
    final pos = segment.nodeAt(index);
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
                  'Capítulo $chapter',
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
                'MUNDO ${_controller.selectedWorld}',
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
                    'MUNDO $worldNum',
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
            ? Text(
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
}