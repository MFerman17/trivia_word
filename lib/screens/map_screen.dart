import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/map_controller.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import 'game_screen.dart';

// Colores coherentes con el estilo del juego
const Color kOutline = Color(0xFF0D0326);
const Color kCyan = Color(0xFF1EE3CF);
const Color kBone = Color(0xFFF4EBDD);
const double kSkew = -0.2;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _controller;
  bool _isMuted = AudioService.isMuted;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    _controller.loadAllProgress();
    
    // Inicia la música de fondo al cargar el mapa
    AudioService.playBgm('game_bgm.mp3');
  }

  @override
  void dispose() {
    _controller.dispose();
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
      _controller.loadAllProgress();
      AudioService.playBgm('game_bgm.mp3');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0E17),
          body: Stack(
            children: [
              // 1. FONDO ÉPICO DEL MAPA (puedes usar bg_landscape.png o una variante)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/bg_landscape.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),

              // Capa de oscurecimiento para legibilidad de los nodos
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. CONTENIDO PRINCIPAL (SafeArea)
              SafeArea(
                child: Column(
                  children: [
                    _buildCustomAppBar(),
                    _buildWorldSelector(),
                    Expanded(
                      child: _controller.isLoading
                          ? const Center(child: CircularProgressIndicator(color: kCyan))
                          : _buildZigZagPathMap(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 22),
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
              // Botón de Silencio / Sonido
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
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
              // Medidor de Estrellas Total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
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
        itemCount: 4,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          int worldNum = index + 1;
          bool isSelected = worldNum == _controller.selectedWorld;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: InkWell(
              onTap: () => _controller.selectWorld(worldNum),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [Color(0xFF00FFA3), Color(0xFF00B8FF)])
                      : LinearGradient(colors: [const Color(0xFF2B2B48), Colors.black.withValues(alpha: 0.6)]),
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
  // MAPA EN ZIGZAG DE NODOS
  // =================================================================
  Widget _buildZigZagPathMap() {
    List<StageProgress> worldStages = [];

    for (int c = 1; c <= 3; c++) {
      for (int l = 1; l <= 5; l++) {
        worldStages.add(
          _controller.getProgressForNode(_controller.selectedWorld, c, l)
        );
      }
    }

    return ListView.builder(
      reverse: true, // Empieza desde abajo
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      itemCount: worldStages.length,
      itemBuilder: (context, index) {
        StageProgress progress = worldStages[index];

        // Patrón en zigzag visual
        int positionPattern = index % 4;
        Alignment nodeAlignment;
        if (positionPattern == 0) {
          nodeAlignment = Alignment.centerLeft;
        } else if (positionPattern == 1 || positionPattern == 3) {
          nodeAlignment = Alignment.center;
        } else {
          nodeAlignment = Alignment.centerRight;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 18),
          child: Align(
            alignment: nodeAlignment,
            child: _buildPathNode(progress, index + 1),
          ),
        );
      },
    );
  }

  // =================================================================
  // NODO INDIVIDUAL DE NIVEL
  // =================================================================
  Widget _buildPathNode(StageProgress progress, int displayIndex) {
    bool unlocked = progress.isUnlocked;

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
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF9DFF7A), Color(0xFF00B8FF)],
                    )
                  : LinearGradient(
                      colors: [Colors.grey.shade800, Colors.black],
                    ),
              border: Border.all(
                color: unlocked ? Colors.amberAccent : Colors.grey.shade600,
                width: 3.5,
              ),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00FFA3).withValues(alpha: 0.5),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: unlocked
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$displayIndex',
                          style: GoogleFonts.anton(
                            color: kOutline,
                            fontSize: 24,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'C${progress.chapterId}.L${progress.levelNumber}',
                          style: GoogleFonts.oswald(
                            color: kOutline,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Icon(Icons.lock_rounded, color: Colors.white38, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Estrellas obtenidas
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (starIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                starIndex < progress.stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16,
                color: starIndex < progress.stars ? Colors.amberAccent : Colors.white30,
              ),
            );
          }),
        ),
      ],
    );
  }
}