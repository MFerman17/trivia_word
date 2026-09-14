import 'package:flutter/foundation.dart';
import '../models/stage_progress.dart';
import '../services/save_service.dart';

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
      for (int c = 1; c <= 3; c++) {
        for (int l = 1; l <= 5; l++) {
          StageProgress p = await SaveService.getStageProgress(w, c, l);
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
}