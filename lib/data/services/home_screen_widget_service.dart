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
  static const String widgetRemainingTimeKey = 'widget_remaining_time';
  static const String widgetNextPrayerTargetMillisKey =
      'widget_next_prayer_target_millis';
  static const String widgetPrayerScheduleKey = 'widget_prayer_schedule';
  static const String androidWidgetProviderName =
      'com.veles.ezanvakti.PrayerTimesWidgetProvider';

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
        await _saveSafeWidgetData();
        return;
      }

      final dailyPrayerTimes = await _loadPrayerTimes(city);
      final nextPrayerInfo = _findNextPrayerInfo(dailyPrayerTimes);
      if (nextPrayerInfo == null) {
        debugPrint('Widget güncellenemedi: sonraki vakit bulunamadı.');
        await _saveSafeWidgetData();
        return;
      }

      await _saveWidgetData(
        cityName: dailyPrayerTimes.city,
        nextPrayerName: nextPrayerInfo.prayerTime.name,
        nextPrayerTime: nextPrayerInfo.prayerTime.formattedTime,
        remainingTime: _formatRemainingTime(nextPrayerInfo.dateTime),
        nextPrayerTargetMillis:
            nextPrayerInfo.dateTime.millisecondsSinceEpoch.toString(),
        prayerSchedule: _serializePrayerSchedule(dailyPrayerTimes),
      );
    } catch (error, stackTrace) {
      debugPrint('Android ana ekran widget güncellenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _saveSafeWidgetData();
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

  _NextPrayerInfo? _findNextPrayerInfo(DailyPrayerTimes dailyPrayerTimes) {
    if (dailyPrayerTimes.prayerTimes.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    for (final prayerTime in dailyPrayerTimes.prayerTimes) {
      final prayerDateTime = prayerTime.dateTimeOn(dailyPrayerTimes.date);
      if (prayerDateTime.isAfter(now)) {
        return _NextPrayerInfo(
          prayerTime: prayerTime,
          dateTime: prayerDateTime,
        );
      }
    }

    final firstPrayer = dailyPrayerTimes.prayerTimes.first;
    final tomorrow = dailyPrayerTimes.date.add(const Duration(days: 1));
    return _NextPrayerInfo(
      prayerTime: firstPrayer,
      dateTime: firstPrayer.dateTimeOn(tomorrow),
    );
  }

  String _formatRemainingTime(DateTime targetDateTime) {
    final remaining = targetDateTime.difference(DateTime.now());
    if (remaining.inMinutes < 1) {
      return 'Vakit girdi';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final fullText = hours > 0
        ? '$hours saat $minutes dakika kaldı'
        : '$minutes dakika kaldı';

    if (fullText.length <= 16) {
      return fullText;
    }

    return hours > 0 ? '${hours}s ${minutes}dk kaldı' : '${minutes}dk kaldı';
  }

  Future<void> _saveWidgetData({
    required String cityName,
    required String nextPrayerName,
    required String nextPrayerTime,
    required String remainingTime,
    required String nextPrayerTargetMillis,
    required String prayerSchedule,
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
    await _homeWidgetClient.saveWidgetData(
      widgetRemainingTimeKey,
      remainingTime,
    );
    await _homeWidgetClient.saveWidgetData(
      widgetNextPrayerTargetMillisKey,
      nextPrayerTargetMillis,
    );
    await _homeWidgetClient.saveWidgetData(
      widgetPrayerScheduleKey,
      prayerSchedule,
    );
    await _homeWidgetClient.updateWidget(
      qualifiedAndroidName: androidWidgetProviderName,
    );
  }

  Future<void> _saveSafeWidgetData() async {
    try {
      await _saveWidgetData(
        cityName: 'Ezan Vakti',
        nextPrayerName: '--',
        nextPrayerTime: '--:--',
        remainingTime: '--',
        nextPrayerTargetMillis: '0',
        prayerSchedule: '',
      );
    } catch (error, stackTrace) {
      debugPrint('Güvenli widget verisi yazılamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool get _supportsAndroidHomeWidget {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  String _serializePrayerSchedule(DailyPrayerTimes dailyPrayerTimes) {
    return dailyPrayerTimes.prayerTimes.map((prayerTime) {
      final targetMillis = prayerTime
          .dateTimeOn(dailyPrayerTimes.date)
          .millisecondsSinceEpoch
          .toString();
      return '${_cleanSchedulePart(prayerTime.name)}|'
          '${_cleanSchedulePart(prayerTime.formattedTime)}|'
          '$targetMillis';
    }).join(';');
  }

  String _cleanSchedulePart(String value) {
    return value.replaceAll('|', ' ').replaceAll(';', ' ').trim();
  }
}

class _NextPrayerInfo {
  const _NextPrayerInfo({
    required this.prayerTime,
    required this.dateTime,
  });

  final PrayerTime prayerTime;
  final DateTime dateTime;
}
