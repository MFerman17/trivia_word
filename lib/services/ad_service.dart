import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ads_config.dart';
import 'age_gate_service.dart';
import 'analytics_service.dart';
import 'vip_service.dart';

/// Rewarded AdMob ads used by the Android shop.
/// Google sample IDs are deliberately used until production IDs are supplied.
class AdService {
  static const String _testRewardedAndroidId =
      'ca-app-pub-3940256099942544/5224354917';
  // El ID real se pega en lib/config/ads_config.dart. Se puede seguir
  // pasando al compilar con --dart-define, que tiene prioridad.
  static const String _productionRewardedAndroidId = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID_ID',
    defaultValue: kAdmobRewardedAndroidId,
  );

  static String get _rewardedAndroidId => kReleaseMode
      ? _productionRewardedAndroidId
      : _testRewardedAndroidId;

  static Future<void>? _initialization;
  static RewardedAd? _cachedAd;
  static bool _isLoading = false;

  static Future<void> initialize() {
    if (defaultTargetPlatform != TargetPlatform.android) return Future.value();
    // Hasta saber la edad no se pide ningún anuncio (se vuelve a llamar
    // cuando el jugador responde la pantalla de edad).
    if (!AgeGateService.answered) return Future.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      // En Europa (RGPD) hay que preguntar antes de mostrar anuncios. El
      // formulario lo gestiona Google (UMP) y solo aparece donde la ley lo
      // exige; su texto se configura en AdMob → Privacidad y mensajes.
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      // Menores de 13: anuncios para niños (sin personalizar, aptos para
      // todos). Resto: como mucho contenido para adolescentes ("T"), porque
      // el juego lo puede jugar cualquiera.
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
        // Sustituye a los antiguos tagForChildDirectedTreatment y
        // tagForUnderAgeOfConsent (obsoletos desde google_mobile_ads 9).
        ageRestrictedTreatment: AgeGateService.isChild
            ? AgeRestrictedTreatment.child
            : AgeRestrictedTreatment.unspecified,
        maxAdContentRating: AgeGateService.isChild ? MaxAdContentRating.g : MaxAdContentRating.t,
      ));
      await _loadRewardedAd();
    } catch (error) {
      debugPrint('No se pudo inicializar AdMob: $error');
    }
  }

  /// Pide (si hace falta) el consentimiento de anuncios del jugador.
  static Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      // Para menores no se muestra el formulario de consentimiento: sus
      // anuncios ya van sin personalizar.
      ConsentRequestParameters(tagForUnderAgeOfConsent: AgeGateService.isChild),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('Formulario de consentimiento: ${error.message}');
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError error) {
        debugPrint('No se pudo actualizar el consentimiento: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  /// true si el jugador debe poder cambiar su consentimiento desde Ajustes
  /// (Google lo exige en los países donde se pidió).
  static Future<bool> privacyOptionsRequired() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Vuelve a mostrar el formulario de privacidad de anuncios.
  static Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('Opciones de privacidad: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  // ------------------------------------------------------------------
  // LÍMITES DIARIOS
  // Algunos premios por video no tenían tope (pociones y pistas de la
  // tienda, vida extra). Con el Pase VIP serían infinitos, y además ver
  // demasiados videos seguidos hace que AdMob pague menos por cada uno.
  // ------------------------------------------------------------------

  /// Topes: pociones y pistas de la tienda (cada una) y vida extra.
  static const int shopVideosPerDay = 5;
  static const int lifeVideosPerDay = 5;

  static String _limitKey(String placement) {
    final n = DateTime.now();
    return 'adlimit_${placement}_${n.year}-${n.month}-${n.day}';
  }

  /// Cuántas veces quedan hoy para [placement] con un tope de [max].
  static Future<int> remainingToday(String placement, int max) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (max - (prefs.getInt(_limitKey(placement)) ?? 0)).clamp(0, max);
    } catch (_) {
      return max;
    }
  }

  static Future<void> _countUse(String placement) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _limitKey(placement);
      await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    } catch (_) {}
  }

  static Future<void> _loadRewardedAd() async {
    if (VipService.isVip) return; // el VIP no necesita videos cargados
    if (_rewardedAndroidId.isEmpty || _isLoading || _cachedAd != null) return;
    _isLoading = true;
    final loaded = Completer<void>();

    RewardedAd.load(
      adUnitId: _rewardedAndroidId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _cachedAd = ad;
          _isLoading = false;
          if (!loaded.isCompleted) loaded.complete();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('No se pudo cargar el anuncio recompensado: $error');
          if (!loaded.isCompleted) loaded.complete();
        },
      ),
    );

    await loaded.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _isLoading = false;
      },
    );
  }

  /// Devuelve true solo cuando AdMob confirma que el jugador vio el video
  /// entero, o al instante si tiene el Pase VIP.
  ///
  /// [placement] es el sitio del juego (para la analítica). Si se da
  /// [dailyLimit], también se respeta un tope de veces al día.
  static Future<bool> showRewardedAd({String placement = 'other', int? dailyLimit}) async {
    if (dailyLimit != null && await remainingToday(placement, dailyLimit) <= 0) return false;
    final earned = await _showRewardedAd();
    if (earned) {
      AnalyticsService.adReward(placement, vip: VipService.isVip);
      if (dailyLimit != null) await _countUse(placement);
    }
    return earned;
  }

  static Future<bool> _showRewardedAd() async {
    if (VipService.isVip) {
      // Una pausa breve para que se note que "pasó algo".
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return true;
    }
    if (defaultTargetPlatform != TargetPlatform.android ||
        _rewardedAndroidId.isEmpty) {
      return false;
    }
    await initialize();
    if (_cachedAd == null) await _loadRewardedAd();

    final ad = _cachedAd;
    if (ad == null) return false;

    _cachedAd = null;
    final result = Completer<bool>();
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        _loadRewardedAd();
        if (!result.isCompleted) result.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        debugPrint('No se pudo mostrar el anuncio: $error');
        shownAd.dispose();
        _loadRewardedAd();
        if (!result.isCompleted) result.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (_, _) {
          earnedReward = true;
        },
      );
      return await result.future;
    } catch (error) {
      debugPrint('Error mostrando anuncio recompensado: $error');
      ad.dispose();
      _loadRewardedAd();
      return false;
    }
  }
}
