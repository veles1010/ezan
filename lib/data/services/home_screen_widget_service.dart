import 'package:flutter/foundation.dart';

import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';
import '../repositories/api_prayer_times_repository.dart';
import '../repositories/mock_prayer_times_repository.dart';
import '../repositories/prayer_times_repository.dart';
import 'home_widget_client.dart';
import 'selected_city_service.dart';

class HomeScreenWidgetService {
  HomeScreenWidgetService({
    SelectedCityService? selectedCityService,
    PrayerTimesRepository? repository,
    PrayerTimesRepository? fallbackRepository,
    HomeWidgetClient? homeWidgetClient,
  })  : _selectedCityService = selectedCityService ?? SelectedCityService(),
        _repository = repository ?? ApiPrayerTimesRepository(),
        _fallbackRepository = fallbackRepository ?? MockPrayerTimesRepository(),
        _homeWidgetClient = homeWidgetClient ?? const HomeWidgetClient();

  static const String widgetCityNameKey = 'widget_city_name';
  static const String widgetNextPrayerNameKey = 'widget_next_prayer_name';
  static const String widgetNextPrayerTimeKey = 'widget_next_prayer_time';
  static const String androidWidgetProviderName =
      'com.example.ezan_vakti.PrayerTimesWidgetProvider';

  final SelectedCityService _selectedCityService;
  final PrayerTimesRepository _repository;
  final PrayerTimesRepository _fallbackRepository;
  final HomeWidgetClient _homeWidgetClient;

  Future<void> updatePrayerTimesWidgetFromSelectedCity() async {
    if (!_supportsAndroidHomeWidget) {
      return;
    }

    try {
      final city = await _selectedCityService.readSelectedCity();
      if (city == null || city.isEmpty) {
        debugPrint('Widget güncellenemedi: seçili şehir bulunamadı.');
        return;
      }

      final dailyPrayerTimes = await _loadPrayerTimes(city);
      final nextPrayer = _findNextPrayer(dailyPrayerTimes);
      if (nextPrayer == null) {
        debugPrint('Widget güncellenemedi: sonraki vakit bulunamadı.');
        return;
      }

      await _saveWidgetData(
        cityName: dailyPrayerTimes.city,
        nextPrayerName: nextPrayer.name,
        nextPrayerTime: nextPrayer.formattedTime,
      );
    } catch (error, stackTrace) {
      debugPrint('Android ana ekran widget güncellenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<DailyPrayerTimes> _loadPrayerTimes(String city) async {
    final date = DateTime.now();

    try {
      return await _repository.getDailyPrayerTimes(city: city, date: date);
    } catch (apiError, stackTrace) {
      debugPrint('Widget API verisi alamadı, mock veriye geçiliyor: $apiError');
      debugPrintStack(stackTrace: stackTrace);
      return _fallbackRepository.getDailyPrayerTimes(city: city, date: date);
    }
  }

  PrayerTime? _findNextPrayer(DailyPrayerTimes dailyPrayerTimes) {
    if (dailyPrayerTimes.prayerTimes.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    for (final prayerTime in dailyPrayerTimes.prayerTimes) {
      if (prayerTime.dateTimeOn(dailyPrayerTimes.date).isAfter(now)) {
        return prayerTime;
      }
    }

    return dailyPrayerTimes.prayerTimes.first;
  }

  Future<void> _saveWidgetData({
    required String cityName,
    required String nextPrayerName,
    required String nextPrayerTime,
  }) async {
    await _homeWidgetClient.saveWidgetData(widgetCityNameKey, cityName);
    await _homeWidgetClient.saveWidgetData(
      widgetNextPrayerNameKey,
      nextPrayerName,
    );
    await _homeWidgetClient.saveWidgetData(
      widgetNextPrayerTimeKey,
      nextPrayerTime,
    );
    await _homeWidgetClient.updateWidget(
      qualifiedAndroidName: androidWidgetProviderName,
    );
  }

  bool get _supportsAndroidHomeWidget {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }
}
