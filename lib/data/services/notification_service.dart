import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    await _requestRuntimePermissions();
    _isInitialized = true;
  }

  Future<void> schedulePrayerReminders(
    DailyPrayerTimes dailyPrayerTimes, {
    required int minutesBefore,
  }) async {
    if (kIsWeb) {
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    await _plugin.cancelAll();
    final now = DateTime.now();

    for (final prayerTime in dailyPrayerTimes.prayerTimes) {
      final scheduledDate = prayerTime
          .dateTimeOn(dailyPrayerTimes.date)
          .subtract(Duration(minutes: minutesBefore));

      if (scheduledDate.isBefore(now)) {
        continue;
      }

      await _plugin.zonedSchedule(
        _notificationId(dailyPrayerTimes.city, prayerTime),
        '${prayerTime.name} vakti yaklaşıyor',
        '${dailyPrayerTimes.city} için ${prayerTime.formattedTime} vaktine '
            '$minutesBefore dakika kaldı.',
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_reminders',
            'Namaz Hatırlatmaları',
            channelDescription: 'Namaz vakitlerinden önce uyarı gönderir.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelPrayerReminders() async {
    if (kIsWeb) {
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    await _plugin.cancelAll();
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timezoneName = timezoneInfo is String
          ? timezoneInfo
          : timezoneInfo.name as String;
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Varsayılan timezone ile devam edilir.
    }
  }

  Future<void> _requestRuntimePermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin
    >();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  int _notificationId(String city, PrayerTime prayerTime) {
    return '${city}_${prayerTime.name}_${prayerTime.hour}_${prayerTime.minute}'
            .hashCode &
        0x7fffffff;
  }
}
