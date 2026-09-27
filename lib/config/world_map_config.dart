import 'package:flutter/material.dart';

/// Niveles por capítulo y capítulos por mundo (3 x 5 = 15 niveles).
const int kLevelsPerChapter = 5;
const int kChaptersPerWorld = 3;

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

  const MapSegment({
    required this.asset,
    required this.nodes,
    this.mirrored = false,
  });

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
  Offset(0.543, 0.769),
  Offset(0.419, 0.647),
  Offset(0.534, 0.535),
  Offset(0.446, 0.417),
  Offset(0.530, 0.325),
];
const List<Offset> _bosque2 = [
  Offset(0.478, 0.821),
  Offset(0.305, 0.525),
  Offset(0.495, 0.494),
  Offset(0.630, 0.371),
  Offset(0.488, 0.196),
];
const List<Offset> _bosque3 = [
  Offset(0.385, 0.745),
  Offset(0.579, 0.703),
  Offset(0.444, 0.563),
  Offset(0.341, 0.447),
  Offset(0.432, 0.270),
];

// ---------- Mundo 2: Cavernas ----------
const List<Offset> _cavernas1 = [
  Offset(0.493, 0.766),
  Offset(0.333, 0.712),
  Offset(0.398, 0.518),
  Offset(0.497, 0.356),
  Offset(0.496, 0.248),
];
const List<Offset> _cavernas2 = [
  Offset(0.432, 0.778),
  Offset(0.550, 0.647),
  Offset(0.444, 0.482),
  Offset(0.542, 0.331),
  Offset(0.450, 0.194),
];
const List<Offset> _cavernas3 = [
  Offset(0.584, 0.791),
  Offset(0.504, 0.694),
  Offset(0.589, 0.555),
  Offset(0.486, 0.448),
  Offset(0.542, 0.352),
];

// ---------- Mundo 3: Islas Flotantes ----------
const List<Offset> _islas1 = [
  Offset(0.409, 0.787),
  Offset(0.486, 0.611),
  Offset(0.464, 0.451),
  Offset(0.589, 0.337),
  Offset(0.491, 0.258),
];
const List<Offset> _islas2 = [
  Offset(0.522, 0.733),
  Offset(0.433, 0.601),
  Offset(0.494, 0.502),
  Offset(0.436, 0.382),
  Offset(0.522, 0.286),
];
const List<Offset> _islas3 = [
  Offset(0.654, 0.721),
  Offset(0.446, 0.619),
  Offset(0.530, 0.481),
  Offset(0.442, 0.343),
  Offset(0.525, 0.244),
];

// ---------- Mundo 4: Volcán ----------
const List<Offset> _volcan1 = [
  Offset(0.493, 0.707),
  Offset(0.421, 0.514),
  Offset(0.591, 0.472),
  Offset(0.386, 0.361),
  Offset(0.577, 0.249),
];
const List<Offset> _volcan2 = [
  Offset(0.475, 0.695),
  Offset(0.508, 0.524),
  Offset(0.447, 0.412),
  Offset(0.494, 0.288),
  Offset(0.491, 0.204),
];
const List<Offset> _volcan3 = [
  Offset(0.492, 0.790),
  Offset(0.216, 0.688),
  Offset(0.581, 0.677),
  Offset(0.412, 0.496),
  Offset(0.478, 0.412),
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
};