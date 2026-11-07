import 'package:flutter/material.dart';

import '../services/asset_catalog.dart';

/// Número de mundos del juego. Para añadir uno: su entrada en kWorldMaps,
/// su nombre (worldNameN), su jefe (bossWorldN), sus mini retos (miniN1-3),
/// sus historias (storyN1-3) y sus monstruos en QuestionBank.
const int kWorldCount = 6;

/// Niveles por capítulo y capítulos por mundo (3 x 10 = 30 niveles).
/// El último nivel de cada capítulo es una pelea (ver FighterService).
const int kLevelsPerChapter = 10;
const int kChaptersPerWorld = 3;

/// Cada imagen de sendero tiene 5 plataformas dibujadas. Un capítulo de 10
/// niveles usa su imagen dos veces: la normal (niveles 1-5) y encima la
/// misma en espejo (niveles 6-10), así el camino no parece repetido.
const int kNodesPerSegment = 5;
const int kSegmentsPerChapter = kLevelsPerChapter ~/ kNodesPerSegment;

/// Un tramo del sendero: una imagen de fondo + la posición de sus 5 nodos.
///
/// Coordenadas RELATIVAS a la imagen original (0.0 a 1.0):
///   dx = 0 borde izquierdo, 1 borde derecho
///   dy = 0 borde superior, 1 borde inferior
/// Ordenadas de ABAJO hacia ARRIBA, siguiendo el recorrido del jugador.
class MapSegment {
  final String asset;
  final bool mirrored;
  final List<Offset> nodes;

  /// Tramo que se usa mientras la imagen de [asset] no exista en el juego
  /// (mundos nuevos cuyas imágenes aún no se han hecho).
  final MapSegment? fallback;

  const MapSegment({
    required this.asset,
    required this.nodes,
    this.mirrored = false,
    this.fallback,
  });

  /// Este tramo si su imagen existe; si no, el de reserva.
  MapSegment get resolved =>
      fallback == null || AssetCatalog.has(asset) ? this : fallback!.resolved;

  Offset nodeAt(int i) {
    final p = nodes[i];
    return mirrored ? Offset(1 - p.dx, p.dy) : p;
  }
}

// =================================================================
// COORDENADAS DE LOS CÍRCULOS (medidas sobre las imágenes 1248x832)
// =================================================================

// ---------- Mundo 1: Bosque ----------
const List<Offset> _bosque1 = [
  Offset(0.551, 0.752),
  Offset(0.405, 0.626),
  Offset(0.537, 0.506),
  Offset(0.437, 0.386),
  Offset(0.533, 0.290),
];
const List<Offset> _bosque2 = [
  Offset(0.551, 0.758),
  Offset(0.405, 0.627),
  Offset(0.537, 0.510),
  Offset(0.437, 0.387),
  Offset(0.533, 0.292),
];
const List<Offset> _bosque3 = [
  Offset(0.535, 0.762),
  Offset(0.395, 0.623),
  Offset(0.611, 0.502),
  Offset(0.442, 0.386),
  Offset(0.530, 0.291),
];

// ---------- Mundo 2: Cavernas ----------
const List<Offset> _cavernas1 = [
  Offset(0.502, 0.780),
  Offset(0.333, 0.577),
  Offset(0.616, 0.505),
  Offset(0.419, 0.349),
  Offset(0.574, 0.237),
];
const List<Offset> _cavernas2 = [
  Offset(0.449, 0.772),
  Offset(0.676, 0.553),
  Offset(0.361, 0.429),
  Offset(0.681, 0.320),
  Offset(0.420, 0.189),
];
const List<Offset> _cavernas3 = [
  Offset(0.497, 0.785),
  Offset(0.665, 0.593),
  Offset(0.281, 0.505),
  Offset(0.400, 0.313),
  Offset(0.623, 0.224),
];

// ---------- Mundo 3: Islas Flotantes ----------
const List<Offset> _islas1 = [
  Offset(0.208, 0.686),
  Offset(0.507, 0.686),
  Offset(0.769, 0.481),
  Offset(0.356, 0.372),
  Offset(0.622, 0.221),
];
const List<Offset> _islas2 = [
  Offset(0.190, 0.537),
  Offset(0.315, 0.308),
  Offset(0.513, 0.449),
  Offset(0.705, 0.622),
  Offset(0.860, 0.353),
];
const List<Offset> _islas3 = [
  Offset(0.208, 0.686),
  Offset(0.507, 0.686),
  Offset(0.769, 0.478),
  Offset(0.356, 0.372),
  Offset(0.622, 0.221),
];

// ---------- Mundo 4: Volcán ----------
const List<Offset> _volcan1 = [
  Offset(0.534, 0.729),
  Offset(0.377, 0.561),
  Offset(0.564, 0.462),
  Offset(0.424, 0.356),
  Offset(0.558, 0.248),
];
const List<Offset> _volcan2 = [
  Offset(0.154, 0.413),
  Offset(0.367, 0.519),
  Offset(0.537, 0.375),
  Offset(0.672, 0.530),
  Offset(0.828, 0.417),
];
const List<Offset> _volcan3 = [
  Offset(0.154, 0.405),
  Offset(0.375, 0.497),
  Offset(0.535, 0.346),
  Offset(0.668, 0.505),
  Offset(0.828, 0.371),
];

// ---------- Mundo 5: Desierto (medido sobre las imágenes nuevas) ----------
const List<Offset> _desierto1 = [
  Offset(0.491, 0.825),
  Offset(0.459, 0.569),
  Offset(0.516, 0.385),
  Offset(0.494, 0.244),
  Offset(0.588, 0.144),
];
const List<Offset> _desierto2 = [
  Offset(0.085, 0.665),
  Offset(0.290, 0.565),
  Offset(0.515, 0.462),
  Offset(0.737, 0.370),
  Offset(0.917, 0.278),
];
const List<Offset> _desierto3 = [
  Offset(0.411, 0.745),
  Offset(0.585, 0.601),
  Offset(0.467, 0.473),
  Offset(0.657, 0.372),
  Offset(0.638, 0.272),
];

// ---------- Mundo 6: Glaciar ----------
// Posiciones provisionales (sendero en zigzag por la franja central, como
// pide la guía de estilo). Se miden de nuevo cuando lleguen las imágenes.
const List<Offset> _provisional = [
  Offset(0.500, 0.780),
  Offset(0.400, 0.640),
  Offset(0.560, 0.510),
  Offset(0.430, 0.380),
  Offset(0.520, 0.250),
];

// =================================================================
// MUNDOS (capítulo 1 abajo, capítulo 3 arriba)
// Los nombres respetan mayúsculas: Flutter distingue 'Bosque_1' de 'bosque_1'.
// =================================================================
final Map<int, List<MapSegment>> kWorldMaps = {
  1: const [
    MapSegment(asset: 'assets/images/Bosque_1.png', nodes: _bosque1),
    MapSegment(asset: 'assets/images/Bosque_2.png', nodes: _bosque2),
    MapSegment(asset: 'assets/images/Bosque_3.png', nodes: _bosque3),
  ],
  2: const [
    MapSegment(asset: 'assets/images/Cavernas_1.png', nodes: _cavernas1),
    MapSegment(asset: 'assets/images/Cavernas_2.png', nodes: _cavernas2),
    MapSegment(asset: 'assets/images/Cavernas_3.png', nodes: _cavernas3),
  ],
  3: const [
    MapSegment(asset: 'assets/images/Islas_1.png', nodes: _islas1),
    MapSegment(asset: 'assets/images/Islas_2.png', nodes: _islas2),
    MapSegment(asset: 'assets/images/Islas_3.png', nodes: _islas3),
  ],
  4: const [
    MapSegment(asset: 'assets/images/Volcan_1.png', nodes: _volcan1),
    MapSegment(asset: 'assets/images/Volcan_2.png', nodes: _volcan2),
    MapSegment(asset: 'assets/images/Volcan_3.png', nodes: _volcan3),
  ],
  // Las imágenes nuevas van en assets/images/maps/. Mientras no estén, se
  // ve el mapa de reserva (volcán para el desierto, islas para el glaciar).
  5: const [
    MapSegment(
      asset: 'assets/images/maps/Desierto_1.png',
      nodes: _desierto1,
      fallback: MapSegment(asset: 'assets/images/Volcan_1.png', nodes: _volcan1),
    ),
    MapSegment(
      asset: 'assets/images/maps/Desierto_2.png',
      nodes: _desierto2,
      fallback: MapSegment(asset: 'assets/images/Volcan_2.png', nodes: _volcan2),
    ),
    MapSegment(
      asset: 'assets/images/maps/Desierto_3.png',
      nodes: _desierto3,
      fallback: MapSegment(asset: 'assets/images/Volcan_3.png', nodes: _volcan3),
    ),
  ],
  6: const [
    MapSegment(
      asset: 'assets/images/maps/Glaciar_1.png',
      nodes: _provisional,
      fallback: MapSegment(asset: 'assets/images/Islas_1.png', nodes: _islas1),
    ),
    MapSegment(
      asset: 'assets/images/maps/Glaciar_2.png',
      nodes: _provisional,
      fallback: MapSegment(asset: 'assets/images/Islas_2.png', nodes: _islas2),
    ),
    MapSegment(
      asset: 'assets/images/maps/Glaciar_3.png',
      nodes: _provisional,
      fallback: MapSegment(asset: 'assets/images/Islas_3.png', nodes: _islas3),
    ),
  ],
};

/// Tramos de un mundo, ya con los de reserva donde falte la imagen.
List<MapSegment> worldSegments(int world) =>
    (kWorldMaps[world] ?? kWorldMaps[1]!).map((s) => s.resolved).toList();