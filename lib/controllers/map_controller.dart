import 'package:flutter/foundation.dart';
import '../models/stage_progress.dart';
import '../services/save_service.dart';
import '../config/world_map_config.dart';

class MapController extends ChangeNotifier {
  int selectedWorld = 1;
  int totalStars = 0;
  bool isLoading = true;

  final Map<String, StageProgress> stagesProgress = {};

  /// Carga el progreso de todos los niveles y el total de estrellas
  Future<void> loadAllProgress() async {
    isLoading = true;
    notifyListeners();

    int stars = await SaveService.getTotalStarsObtained();
    stagesProgress.clear();

    for (int w = 1; w <= 4; w++) {
      for (int c = 1; c <= kChaptersPerWorld; c++) {
        for (int l = 1; l <= kLevelsPerChapter; l++) {
          StageProgress p = await SaveService.getStageProgress(w, c, l);
          // Al pasar de 5 a 10 niveles por capítulo, quien ya había ganado el
          // antiguo nivel 5 tendría el 6 bloqueado. Regla: un nivel ganado
          // siempre deja abierto el siguiente del mismo capítulo.
          if (l > 1 && !p.isUnlocked) {
            final previous = stagesProgress['w${w}_c${c}_l${l - 1}'];
            if (previous != null && previous.stars > 0) {
              p = StageProgress(
                worldId: w,
                chapterId: c,
                levelNumber: l,
                stars: p.stars,
                highScore: p.highScore,
                isUnlocked: true,
              );
              await SaveService.saveStageProgress(p);
            }
          }
          stagesProgress[p.stageKey] = p;
        }
      }
    }

    totalStars = stars;
    isLoading = false;
    notifyListeners();
  }

  /// Cambia el mundo seleccionado en el mapa
  void selectWorld(int worldNum) {
    if (selectedWorld != worldNum) {
      selectedWorld = worldNum;
      notifyListeners();
    }
  }

  /// Obtiene el estado de un nivel específico o devuelve uno por defecto
  StageProgress getProgressForNode(int world, int chapter, int level) {
    String key = 'w${world}_c${chapter}_l$level';
    StageProgress? progress = stagesProgress[key];
    
    // Solo el Mundo 1, Capítulo 1, Nivel 1 está desbloqueado por defecto
    bool defaultUnlocked = (world == 1 && chapter == 1 && level == 1);

    return progress ??
        StageProgress(
          worldId: world,
          chapterId: chapter,
          levelNumber: level,
          stars: 0,
          isUnlocked: defaultUnlocked,
        );
  }

  /// Estrellas ganadas en un mundo (para el candado de las peleas).
  int starsInWorld(int world) {
    var total = 0;
    for (var c = 1; c <= kChaptersPerWorld; c++) {
      for (var l = 1; l <= kLevelsPerChapter; l++) {
        total += getProgressForNode(world, c, l).stars;
      }
    }
    return total;
  }

  bool isWorldUnlocked(int world) {
    if (world == 1) return true;
    return getProgressForNode(world, 1, 1).isUnlocked;
  }
}
