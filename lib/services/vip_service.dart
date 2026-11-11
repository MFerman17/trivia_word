import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// PASE VIP (compra única en Google Play)
///
/// El juego solo tiene videos voluntarios: el jugador elige verlos para
/// ganar un premio. El Pase VIP no "quita anuncios" (no hay ninguno
/// obligatorio): da esos mismos premios AL INSTANTE, sin ver el video.
/// Los límites diarios se mantienen igual, así que el VIP ahorra tiempo
/// pero no rompe la economía del juego.
///
/// Cómo funciona la compra:
///   1. Al abrir el juego se piden a Google Play los datos del producto
///      (precio en la moneda del jugador) y las compras que ya tiene.
///   2. Google avisa de cada compra por [InAppPurchase.purchaseStream].
///   3. Si la compra es del VIP y está pagada, se activa y se guarda.
///   4. Siempre se "completa" la compra: si no, Google la reembolsa sola a
///      los 3 días.
///
/// La compra va con la cuenta de Google del teléfono, no con la partida:
/// en un teléfono nuevo, "Restaurar compras" la recupera.
class VipService {
  VipService._();

  /// ID del producto en Play Console (Monetizar → Productos → Productos
  /// integrados). Debe escribirse EXACTAMENTE igual allí.
  static const String productId = 'vip_pass';

  static const _prefsKey = 'vip_owned';

  /// true si el jugador tiene el VIP. Se puede escuchar para refrescar la
  /// pantalla al comprarlo.
  static final ValueNotifier<bool> owned = ValueNotifier(false);
  static bool get isVip => owned.value;

  /// Datos del producto (precio ya formateado, p. ej. "2,99 €"). null si
  /// Google Play no está disponible o el producto aún no existe.
  static ProductDetails? product;

  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static Completer<bool>? _buying;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      owned.value = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {}
    if (!_supported) return;
    try {
      final iap = InAppPurchase.instance;
      _sub ??= iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('VIP: error en las compras: $e'),
      );
      if (!await iap.isAvailable()) return;
      final response = await iap.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) product = response.productDetails.first;
      // Pide a Google las compras que ya tiene (llegan por purchaseStream).
      await iap.restorePurchases();
    } catch (e) {
      debugPrint('VIP: no se pudo preparar Google Play: $e');
    }
  }

  /// Abre la ventana de pago de Google Play. Devuelve true si el jugador
  /// terminó la compra.
  static Future<bool> buy() async {
    final p = product;
    if (!_supported || p == null || isVip) return isVip;
    if (_buying != null && !_buying!.isCompleted) return _buying!.future;
    _buying = Completer<bool>();
    try {
      final started =
          await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
      if (!started) _finishBuying(false);
    } catch (e) {
      debugPrint('VIP: no se pudo abrir la compra: $e');
      _finishBuying(false);
    }
    return _buying!.future;
  }

  /// Vuelve a pedir a Google las compras hechas (botón de Ajustes).
  static Future<void> restore() async {
    if (!_supported) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('VIP: no se pudieron restaurar las compras: $e');
    }
  }

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == productId) {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final isNew = purchase.status == PurchaseStatus.purchased;
            await _grant();
            if (isNew) AnalyticsService.vipPurchased(product);
            _finishBuying(true);
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            _finishBuying(false);
          case PurchaseStatus.pending:
            // Pago pendiente (p. ej. en efectivo): se activará cuando Google
            // confirme. Mientras, la ventana de compra se da por cerrada.
            _finishBuying(false);
        }
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (e) {
          debugPrint('VIP: no se pudo completar la compra: $e');
        }
      }
    }
  }

  static Future<void> _grant() async {
    owned.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } catch (_) {}
  }

  static void _finishBuying(bool ok) {
    final c = _buying;
    if (c != null && !c.isCompleted) c.complete(ok);
  }
}
