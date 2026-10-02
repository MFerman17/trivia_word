import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Rewarded AdMob ads used by the Android shop.
/// Google sample IDs are deliberately used until production IDs are supplied.
class AdService {
  static const String _testRewardedAndroidId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _productionRewardedAndroidId = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID_ID',
  );

  static String get _rewardedAndroidId => kReleaseMode
      ? _productionRewardedAndroidId
      : _testRewardedAndroidId;

  static Future<void>? _initialization;
  static RewardedAd? _cachedAd;
  static bool _isLoading = false;

  static Future<void> initialize() {
    if (defaultTargetPlatform != TargetPlatform.android) return Future.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
      await _loadRewardedAd();
    } catch (error) {
      debugPrint('No se pudo inicializar AdMob: $error');
    }
  }

  static Future<void> _loadRewardedAd() async {
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

  /// Returns true only after AdMob reports that the user earned the reward.
  static Future<bool> showRewardedAd() async {
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
