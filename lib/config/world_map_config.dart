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
  Offset(0.497, 0.793),
  Offset(0.401, 0.614),
  Offset(0.566, 0.465),
  Offset(0.385, 0.296),
  Offset(0.507, 0.152),
];
const List<Offset> _islas2 = [
  Offset(0.502, 0.841),
  Offset(0.415, 0.617),
  Offset(0.552, 0.462),
  Offset(0.409, 0.296),
  Offset(0.500, 0.128),
];
const List<Offset> _islas3 = [
  Offset(0.497, 0.825),
  Offset(0.411, 0.628),
  Offset(0.558, 0.473),
  Offset(0.406, 0.308),
  Offset(0.511, 0.157),
];

// ---------- Mundo 4: Volcán ----------
const List<Offset> _volcan1 = [
  Offset(0.500, 0.809),
  Offset(0.411, 0.612),
  Offset(0.566, 0.468),
  Offset(0.399, 0.304),
  Offset(0.502, 0.152),
];
const List<Offset> _volcan2 = [
  Offset(0.507, 0.809),
  Offset(0.406, 0.593),
  Offset(0.572, 0.429),
  Offset(0.401, 0.288),
  Offset(0.499, 0.136),
];
const List<Offset> _volcan3 = [
  Offset(0.500, 0.821),
  Offset(0.422, 0.630),
  Offset(0.559, 0.470),
  Offset(0.422, 0.313),
  Offset(0.500, 0.141),
];

// ---------- Mundo 5: Desierto (medido sobre las imágenes nuevas) ----------
const List<Offset> _desierto1 = [
  Offset(0.500, 0.801),
  Offset(0.425, 0.601),
  Offset(0.548, 0.446),
  Offset(0.425, 0.284),
  Offset(0.499, 0.147),
];
const List<Offset> _desierto2 = [
  Offset(0.500, 0.841),
  Offset(0.406, 0.641),
  Offset(0.559, 0.473),
  Offset(0.406, 0.304),
  Offset(0.499, 0.144),
];
const List<Offset> _desierto3 = [
  Offset(0.502, 0.833),
  Offset(0.411, 0.609),
  Offset(0.558, 0.457),
  Offset(0.404, 0.313),
  Offset(0.491, 0.176),
];

// ---------- Mundo 6: Glaciar (medido sobre las imágenes nuevas) ----------
const List<Offset> _glaciar1 = [
  Offset(0.657, 0.817),
  Offset(0.601, 0.633),
  Offset(0.540, 0.470),
  Offset(0.440, 0.296),
  Offset(0.358, 0.144),
];
const List<Offset> _glaciar2 = [
  Offset(0.644, 0.817),
  Offset(0.598, 0.633),
  Offset(0.529, 0.462),
  Offset(0.436, 0.288),
  Offset(0.353, 0.128),
];
const List<Offset> _glaciar3 = [
  Offset(0.644, 0.837),
  Offset(0.598, 0.649),
  Offset(0.543, 0.470),
  Offset(0.440, 0.293),
  Offset(0.353, 0.139),
];
// =================================================================
// MUNDOS (capítulo 1 abajo, capítulo 3 arriba)
// Los nombres respetan mayúsculas: Flutter distingue 'Bosque_1' de 'bosque_1'.
// =================================================================
final Map<int, List<MapSegment>> kWorldMaps = {
  1: const [
    MapSegment(asset: 'assets/images/Bosque_1.jpg', nodes: _bosque1),
    MapSegment(asset: 'assets/images/Bosque_2.jpg', nodes: _bosque2),
    MapSegment(asset: 'assets/images/Bosque_3.jpg', nodes: _bosque3),
  ],
  2: const [
    MapSegment(asset: 'assets/images/Cavernas_1.jpg', nodes: _cavernas1),
    MapSegment(asset: 'assets/images/Cavernas_2.jpg', nodes: _cavernas2),
    MapSegment(asset: 'assets/images/Cavernas_3.jpg', nodes: _cavernas3),
  ],
  3: const [
    MapSegment(asset: 'assets/images/Islas_1.jpg', nodes: _islas1),
    MapSegment(asset: 'assets/images/Islas_2.jpg', nodes: _islas2),
    MapSegment(asset: 'assets/images/Islas_3.jpg', nodes: _islas3),
  ],
  4: const [
    MapSegment(asset: 'assets/images/Volcan_1.jpg', nodes: _volcan1),
    MapSegment(asset: 'assets/images/Volcan_2.jpg', nodes: _volcan2),
    MapSegment(asset: 'assets/images/Volcan_3.jpg', nodes: _volcan3),
  ],
  // Las imágenes nuevas van en assets/images/maps/. Mientras no estén, se
  // ve el mapa de reserva (volcán para el desierto, islas para el glaciar).
  5: const [
    MapSegment(
      asset: 'assets/images/maps/Desierto_1.jpg',
      nodes: _desierto1,
      fallback: MapSegment(asset: 'assets/images/Volcan_1.jpg', nodes: _volcan1),
    ),
    MapSegment(
      asset: 'assets/images/maps/Desierto_2.jpg',
      nodes: _desierto2,
      fallback: MapSegment(asset: 'assets/images/Volcan_2.jpg', nodes: _volcan2),
    ),
    MapSegment(
      asset: 'assets/images/maps/Desierto_3.jpg',
      nodes: _desierto3,
      fallback: MapSegment(asset: 'assets/images/Volcan_3.jpg', nodes: _volcan3),
    ),
  ],
  6: const [
    MapSegment(
      asset: 'assets/images/maps/Glaciar_1.jpg',
      nodes: _glaciar1,
      fallback: MapSegment(asset: 'assets/images/Islas_1.jpg', nodes: _islas1),
    ),
    MapSegment(
      asset: 'assets/images/maps/Glaciar_2.jpg',
      nodes: _glaciar2,
      fallback: MapSegment(asset: 'assets/images/Islas_2.jpg', nodes: _islas2),
    ),
    MapSegment(
      asset: 'assets/images/maps/Glaciar_3.jpg',
      nodes: _glaciar3,
      fallback: MapSegment(asset: 'assets/images/Islas_3.jpg', nodes: _islas3),
    ),
  ],
};

/// Tramos de un mundo, ya con los de reserva donde falte la imagen.
List<MapSegment> worldSegments(int world) =>
    (kWorldMaps[world] ?? kWorldMaps[1]!).map((s) => s.resolved).toList();