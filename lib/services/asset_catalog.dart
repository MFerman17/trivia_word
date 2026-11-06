import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lista de imágenes y sonidos que de verdad vienen dentro del juego.
///
/// Sirve para los mundos y monstruos nuevos: el código ya los conoce, pero
/// sus imágenes llegan después. Si una imagen aún no existe, se usa otra de
/// reserva en lugar de mostrar un hueco o un error.
class AssetCatalog {
  AssetCatalog._();

  static Set<String>? _assets;

  /// Se llama una vez al arrancar (en main).
  static Future<void> init() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _assets = manifest.listAssets().toSet();
    } catch (e) {
      debugPrint('No se pudo leer la lista de recursos: $e');
    }
  }

  /// Si no se pudo leer la lista, se supone que existe (se intenta igual).
  static bool has(String asset) => _assets?.contains(asset) ?? true;

  /// [asset] si existe; si no, [fallback].
  static String pick(String asset, String fallback) =>
      has(asset) ? asset : fallback;
}
