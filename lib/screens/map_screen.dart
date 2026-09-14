import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/map_controller.dart';
import '../models/stage_progress.dart';
import '../services/audio_service.dart';
import 'game_screen.dart';

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
    // Detenemos la música de fondo antes de entrar al nivel
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
      // Al regresar, recargamos el progreso y retomamos la música
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
          appBar: AppBar(
            backgroundColor: const Color(0xFF1F1D36),
            elevation: 0,
            title: Text(
              'Mundo ${_controller.selectedWorld} - Mapa Aventura',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _isMuted ? Colors.redAccent : Colors.amber,
                  size: 26,
                ),
                tooltip: _isMuted ? 'Activar sonido' : 'Silenciar',
                onPressed: () {
                  AudioService.toggleMute();
                  setState(() {
                    _isMuted = AudioService.isMuted;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 24),
                    const SizedBox(width: 6),
                    Text(
                      '${_controller.totalStars}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: _controller.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                )
              : Column(
                  children: [
                    _buildWorldSelector(),
                    Expanded(child: _buildZigZagPathMap()),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWorldSelector() {
    return Container(
      height: 60,
      color: const Color(0xFF1F1D36),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          int worldNum = index + 1;
          bool isSelected = worldNum == _controller.selectedWorld;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 8.0,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? Colors.indigoAccent
                    : const Color(0xFF2B2B48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _controller.selectWorld(worldNum),
              child: Text(
                'Mundo $worldNum',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      itemCount: worldStages.length,
      itemBuilder: (context, index) {
        StageProgress progress = worldStages[index];

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
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: nodeAlignment,
            child: _buildPathNode(progress, index + 1),
          ),
        );
      },
    );
  }

  Widget _buildPathNode(StageProgress progress, int displayIndex) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: progress.isUnlocked
              ? () => _startLevel(
                    progress.worldId,
                    progress.chapterId,
                    progress.levelNumber,
                  )
              : null,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: progress.isUnlocked
                  ? const Color(0xFF6C5CE7)
                  : Colors.grey.shade800,
              border: Border.all(
                color: progress.isUnlocked
                    ? Colors.amberAccent
                    : Colors.grey.shade600,
                width: 3,
              ),
              boxShadow: progress.isUnlocked
                  ? [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: progress.isUnlocked
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$displayIndex',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'C${progress.chapterId}.L${progress.levelNumber}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    )
                  : const Icon(Icons.lock, color: Colors.white38, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (starIndex) {
            return Icon(
              starIndex < progress.stars ? Icons.star : Icons.star_border,
              size: 16,
              color: Colors.amber,
            );
          }),
        ),
      ],
    );
  }
}