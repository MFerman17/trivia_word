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

    stagesProgress.clear();

    for (int w = 1; w <= 4; w++) {
      for (int c = 1; c <= kChaptersPerWorld; c++) {
        for (int l = 1; l <= kLevelsPerChapter; l++) {
          final p = await SaveService.getStageProgress(w, c, l);
          stagesProgress[p.stageKey] = p;
        }
      }
    }
    await _migrateFrom5Levels();

    totalStars = await SaveService.getTotalStarsObtained();
    isLoading = false;
    notifyListeners();
  }

  /// Partidas guardadas cuando los capítulos tenían 5 niveles.
  ///
  /// Los niveles se guardan por número dentro del capítulo, así que el
  /// antiguo capítulo 2 (niveles 1-5) aparece ahora como los niveles 11-15
  /// y el capítulo 3 como los 21-25, con los niveles 6-10 de cada capítulo
  /// vacíos y bloqueados en medio.
  ///
  /// Se reconoce así: el capítulo SIGUIENTE ya está abierto pero el nivel 10
  /// de este no se ha ganado. Con 10 niveles eso es imposible (el siguiente
  /// capítulo solo se abre al ganar el 10), así que es progreso antiguo.
  /// Arreglo: se abren los niveles 6-10 y la pelea que se ganó en el antiguo
  /// nivel 5 pasa al nivel 10 con sus estrellas. Los niveles 6-9 quedan
  /// abiertos para jugarlos.
  ///
  /// Además, un nivel ganado siempre deja abierto el siguiente del capítulo.
  Future<void> _migrateFrom5Levels() async {
    Future<void> put(int w, int c, int l, {required int stars}) async {
      final old = getProgressForNode(w, c, l);
      final p = StageProgress(
        worldId: w,
        chapterId: c,
        levelNumber: l,
        stars: stars,
        highScore: old.highScore,
        isUnlocked: true,
      );
      stagesProgress[p.stageKey] = p;
      await SaveService.saveStageProgress(p);
    }

    for (int w = 1; w <= 4; w++) {
      for (int c = 1; c <= kChaptersPerWorld; c++) {
        final next = c < kChaptersPerWorld
            ? getProgressForNode(w, c + 1, 1)
            : (w < 4 ? getProgressForNode(w + 1, 1, 1) : null);
        final last = getProgressForNode(w, c, kLevelsPerChapter);
        final oldFight = getProgressForNode(w, c, kNodesPerSegment);
        if (next != null && next.isUnlocked && last.stars == 0 && oldFight.stars > 0) {
          for (int l = kNodesPerSegment + 1; l < kLevelsPerChapter; l++) {
            final p = getProgressForNode(w, c, l);
            if (!p.isUnlocked) await put(w, c, l, stars: p.stars);
          }
          await put(w, c, kLevelsPerChapter, stars: oldFight.stars);
        }

        for (int l = 2; l <= kLevelsPerChapter; l++) {
          final p = getProgressForNode(w, c, l);
          if (!p.isUnlocked && getProgressForNode(w, c, l - 1).stars > 0) {
            await put(w, c, l, stars: p.stars);
          }
        }
      }
    }
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
