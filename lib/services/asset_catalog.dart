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

  /// La misma imagen en el formato que haya: primero .webp (el que usa el
  /// juego, pesa menos) y si no .png o .jpg. Así, una imagen nueva que se
  /// añada en PNG (por ejemplo, las de moretones) funciona sin tocar el código.
  static String resolve(String asset) {
    final base = asset.replaceAll(RegExp(r'\.(png|jpg|webp)$'), '');
    for (final ext in const ['.webp', '.png', '.jpg']) {
      if (_assets?.contains('$base$ext') ?? false) return '$base$ext';
    }
    return asset;
  }

  /// [asset] si existe; si no, [fallback].
  static String pick(String asset, String fallback) =>
      has(asset) ? asset : fallback;
}
