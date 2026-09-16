import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static const String androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  static const String androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_AD_UNIT_ID',
  );
  static const String iosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_AD_UNIT_ID',
  );

  static Future<void> initialize() async {
    if (!_isMobilePlatform) {
      return;
    }

    try {
      await MobileAds.instance.initialize();
    } catch (error, stackTrace) {
      debugPrint('AdMob initialize hatası: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static String? get bannerAdUnitId {
    if (!_isMobilePlatform) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (!kReleaseMode) {
          return androidTestBannerAdUnitId;
        }

        return androidBannerAdUnitId.isEmpty ? null : androidBannerAdUnitId;
      case TargetPlatform.iOS:
        if (!kReleaseMode) {
          return iosTestBannerAdUnitId;
        }

        return iosBannerAdUnitId.isEmpty ? null : iosBannerAdUnitId;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }

  static bool get _isMobilePlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
