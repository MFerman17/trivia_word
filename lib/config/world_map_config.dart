import 'package:flutter/material.dart';

/// Niveles por capítulo y capítulos por mundo (3 x 5 = 15 niveles).
const int kLevelsPerChapter = 5;
const int kChaptersPerWorld = 3;

/// Un tramo del sendero: una imagen de fondo + la posición de sus 5 nodos.
///
/// Las coordenadas son RELATIVAS a la imagen original (0.0 a 1.0):
///   dx = 0 borde izquierdo, 1 borde derecho
///   dy = 0 borde superior, 1 borde inferior
/// Se ordenan de ABAJO hacia ARRIBA, siguiendo el recorrido del jugador.
class MapSegment {
  final String asset;
  final bool mirrored; // espejo horizontal para variar un tramo repetido
  final List<Offset> nodes;

  const MapSegment({
    required this.asset,
    required this.nodes,
    this.mirrored = false,
  });

  /// Posición del nodo i ya corregida si el tramo está en espejo.
  Offset nodeAt(int i) {
    final p = nodes[i];
    return mirrored ? Offset(1 - p.dx, p.dy) : p;
  }
}

// Coordenadas APROXIMADAS estimadas a partir de las capturas.
// Afínalas con kMapEditMode = true en map_screen.dart.
const List<Offset> _bosqueNodes = [
  Offset(0.42, 0.72),
  Offset(0.55, 0.62),
  Offset(0.46, 0.50),
  Offset(0.53, 0.42),
  Offset(0.51, 0.27),
];

const List<Offset> _cavernasNodes = [
  Offset(0.56, 0.73),
  Offset(0.34, 0.58),
  Offset(0.59, 0.46),
  Offset(0.37, 0.33),
  Offset(0.57, 0.24),
];

const List<Offset> _islasNodes = [
  Offset(0.24, 0.84),
  Offset(0.40, 0.72),
  Offset(0.72, 0.59),
  Offset(0.48, 0.42),
  Offset(0.52, 0.24),
];

const List<Offset> _volcanNodes = [
  Offset(0.52, 0.73),
  Offset(0.28, 0.66),
  Offset(0.48, 0.44),
  Offset(0.47, 0.31),
  Offset(0.49, 0.19),
];

final Map<int, List<MapSegment>> kWorldMaps = {
  1: [
    MapSegment(asset: 'assets/images/bosque_1.png', nodes: _bosqueNodes),
    MapSegment(asset: 'assets/images/bosque_2.png', nodes: _bosqueNodes),
    MapSegment(asset: 'assets/images/bosque_3.png', nodes: _bosqueNodes),
  ],
  2: [
    MapSegment(asset: 'assets/images/cavernas_1.png', nodes: _cavernasNodes),
    MapSegment(asset: 'assets/images/cavernas_2.png', nodes: _cavernasNodes),
    MapSegment(asset: 'assets/images/cavernas_3.png', nodes: _cavernasNodes),
  ],
  3: [
    MapSegment(asset: 'assets/images/islas_1.png', nodes: _islasNodes),
    MapSegment(asset: 'assets/images/islas_2.png', nodes: _islasNodes),
    MapSegment(asset: 'assets/images/islas_3.png', nodes: _islasNodes),
  ],
  4: [
    MapSegment(asset: 'assets/images/volcan_1.png', nodes: _volcanNodes),
    MapSegment(asset: 'assets/images/volcan_2.png', nodes: _volcanNodes),
    MapSegment(asset: 'assets/images/volcan_3.png', nodes: _volcanNodes),
  ],
};