import 'dart:async';

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
  static const String _umpTestDeviceId = String.fromEnvironment(
    'UMP_TEST_DEVICE_ID',
  );
  static const bool _resetUmpConsentForDebug = bool.fromEnvironment(
    'UMP_TEST_RESET_CONSENT',
  );
  static const bool _forceEeaForDebug = bool.fromEnvironment(
    'UMP_TEST_FORCE_EEA',
  );

  static final ValueNotifier<bool> adsReadyNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<PrivacyOptionsRequirementStatus>
  privacyOptionsRequirementStatus =
      ValueNotifier<PrivacyOptionsRequirementStatus>(
        PrivacyOptionsRequirementStatus.unknown,
      );

  static Future<void>? _initializeFuture;
  static bool _mobileAdsInitialized = false;

  static Future<void> initialize() async {
    if (!_isMobilePlatform) {
      return;
    }

    return _initializeFuture ??= _initializeWithConsent();
  }

  static Future<void> _initializeWithConsent() async {
    final consentInformation = ConsentInformation.instance;
    if (kDebugMode) {
      final testIdentifiers = _umpTestDeviceId.isEmpty
          ? const <String>[]
          : <String>[_umpTestDeviceId];
      debugPrint(
        '[UMP] Debug ayarları: resetRequested=$_resetUmpConsentForDebug, '
        'forceEea=$_forceEeaForDebug, '
        'testIdentifiers=$testIdentifiers',
      );
    }
    if (kDebugMode && _resetUmpConsentForDebug) {
      try {
        await consentInformation.reset();
        debugPrint('[UMP] Debug consent durumu sıfırlandı.');
      } catch (error, stackTrace) {
        debugPrint('UMP test consent durumu sıfırlanamadı: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final previouslyAllowed = await _canRequestAds(consentInformation);
    var canRequestAds = previouslyAllowed;

    try {
      final consentUpdated = await _requestConsentInfoUpdate(
        consentInformation,
      );
      if (consentUpdated) {
        await _logDebugConsentState(
          consentInformation,
          stage: 'Consent bilgisi güncellendi',
        );
        await _loadAndShowConsentFormIfRequired();
      }

      canRequestAds = await _canRequestAds(
        consentInformation,
        fallback: previouslyAllowed,
      );
      await _refreshPrivacyOptionsRequirementStatus(consentInformation);
      await _logDebugConsentState(
        consentInformation,
        stage: 'Consent formu akışı tamamlandı',
      );
    } catch (error, stackTrace) {
      debugPrint('UMP consent işlemi tamamlanamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      canRequestAds = previouslyAllowed;
      await _refreshPrivacyOptionsRequirementStatus(consentInformation);
    }

    if (!canRequestAds || _mobileAdsInitialized) {
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _mobileAdsInitialized = true;
      adsReadyNotifier.value = true;
      if (kDebugMode) {
        debugPrint('[UMP] MobileAds initialize tamamlandı.');
      }
    } catch (error, stackTrace) {
      debugPrint('AdMob initialize hatası: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<bool> _requestConsentInfoUpdate(
    ConsentInformation consentInformation,
  ) {
    final completer = Completer<bool>();
    final shouldUseConsentDebugSettings =
        kDebugMode && (_forceEeaForDebug || _umpTestDeviceId.isNotEmpty);
    final consentDebugSettings = shouldUseConsentDebugSettings
        ? ConsentDebugSettings(
            debugGeography: _forceEeaForDebug
                ? DebugGeography.debugGeographyEea
                : null,
            testIdentifiers: _umpTestDeviceId.isEmpty
                ? null
                : <String>[_umpTestDeviceId],
          )
        : null;
    consentInformation.requestConsentInfoUpdate(
      ConsentRequestParameters(consentDebugSettings: consentDebugSettings),
      () => completer.complete(true),
      (error) {
        debugPrint('UMP consent bilgisi güncellenemedi: $error');
        completer.complete(false);
      },
    );
    return completer.future;
  }

  static Future<void> _loadAndShowConsentFormIfRequired() async {
    final completer = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (kDebugMode) {
        debugPrint(
          '[UMP] loadAndShowConsentFormIfRequired sonucu: '
          'errorCode=${error?.errorCode}, message=${error?.message}',
        );
      }
      if (error != null) {
        debugPrint('UMP consent formu gösterilemedi: $error');
      }
      completer.complete();
    });
    await completer.future;
  }

  static Future<bool> _canRequestAds(
    ConsentInformation consentInformation, {
    bool fallback = false,
  }) async {
    try {
      return await consentInformation.canRequestAds();
    } catch (error, stackTrace) {
      debugPrint('UMP reklam isteği durumu okunamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallback;
    }
  }

  static Future<void> _refreshPrivacyOptionsRequirementStatus(
    ConsentInformation consentInformation,
  ) async {
    try {
      privacyOptionsRequirementStatus.value = await consentInformation
          .getPrivacyOptionsRequirementStatus();
    } catch (error, stackTrace) {
      debugPrint('UMP gizlilik seçenekleri durumu okunamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _logDebugConsentState(
    ConsentInformation consentInformation, {
    required String stage,
  }) async {
    if (!kDebugMode) {
      return;
    }

    try {
      final consentStatus = await consentInformation.getConsentStatus();
      final privacyStatus = await consentInformation
          .getPrivacyOptionsRequirementStatus();
      final canRequestAds = await consentInformation.canRequestAds();
      debugPrint(
        '[UMP] $stage: consentStatus=$consentStatus, '
        'privacyOptionsRequirementStatus=$privacyStatus, '
        'canRequestAds=$canRequestAds',
      );
    } catch (error, stackTrace) {
      debugPrint('[UMP] Debug consent durumu okunamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> showPrivacyOptionsForm() async {
    if (privacyOptionsRequirementStatus.value !=
        PrivacyOptionsRequirementStatus.required) {
      return;
    }

    final completer = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        debugPrint('UMP gizlilik seçenekleri açılamadı: $error');
      }
      completer.complete();
    });
    await completer.future;
    await _refreshPrivacyOptionsRequirementStatus(ConsentInformation.instance);
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
