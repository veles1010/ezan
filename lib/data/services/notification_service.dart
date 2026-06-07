import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';
import 'notification_settings_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const String exactAlarmPermissionMessage =
      'Namaz hatırlatmalarının zamanında gelmesi için Kesin Alarm iznini '
      'açmanız gerekiyor.';
  static const String _exactAlarmPermissionErrorCode =
      'exact_alarms_not_permitted';
  static const String _prayerNotificationIdsPrefsKey =
      'prayer_reminder_notification_ids';
  static const String _fridayNotificationIdsPrefsKey =
      'friday_prayer_reminder_notification_ids';
  static const int _prayerNotificationIdBase = 100000;
  static const int _prayerNotificationIdRange = 100000;
  static const int _fridayNotificationIdBase = 200000;
  static const int _fridayNotificationIdRange = 100000;
  static const int _testNotificationIdBase = 900000;
  static const int _testNotificationIdRange = 100000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Set<int> _scheduledPrayerNotificationIds = <int>{};
  Set<int> _scheduledFridayNotificationIds = <int>{};

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[NOTIFICATION] initialize skipped: already initialized.');
      return;
    }

    debugPrint(
      '[NOTIFICATION] initialize started. '
      'kIsWeb=$kIsWeb, platform=$defaultTargetPlatform',
    );

    if (kIsWeb) {
      debugPrint('[NOTIFICATION] initialize skipped: web platform.');
      _isInitialized = true;
      return;
    }

    await _prepareLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    debugPrint('[NOTIFICATION] FlutterLocalNotificationsPlugin initialized.');
    await _requestRuntimePermissions();
    _isInitialized = true;
    debugPrint('[NOTIFICATION] initialize success.');
  }

  Future<NotificationScheduleResult> schedulePrayerReminders(
    DailyPrayerTimes dailyPrayerTimes, {
    required Map<String, PrayerNotificationSetting> prayerSettings,
    int fridayReminderMinutesBefore = 0,
  }) async {
    if (kIsWeb) {
      debugPrint('[NOTIFICATION] schedulePrayerReminders skipped: web.');
      return const NotificationScheduleResult(scheduledAny: false);
    }

    try {
      debugPrint(
        '[NOTIFICATION] schedulePrayerReminders started. '
        'city=${dailyPrayerTimes.city}, date=${dailyPrayerTimes.date}, '
        'prayerCount=${dailyPrayerTimes.prayerTimes.length}, '
        'prayerSettings=$prayerSettings, '
        'fridayReminderMinutesBefore=$fridayReminderMinutesBefore',
      );

      if (!_isInitialized) {
        debugPrint(
          '[NOTIFICATION] schedulePrayerReminders initializing service.',
        );
        await initialize();
      }

      await _cancelTrackedPrayerReminderNotifications();
      await _cancelTrackedFridayPrayerReminderNotifications();
      final now = DateTime.now();
      var scheduledNotificationCount = 0;
      var scheduledFridayNotificationCount = 0;
      var exactAlarmPermissionRequired = false;
      final scheduledPrayerNotificationIds = <int>{};
      final scheduledFridayNotificationIds = <int>{};

      for (final prayerTime in dailyPrayerTimes.prayerTimes) {
        final prayerSetting = prayerSettings[prayerTime.name] ??
            NotificationSettings.defaultPrayerSetting;
        if (!prayerSetting.enabled) {
          debugPrint(
            '[NOTIFICATION] Prayer reminder skipped: disabled. '
            'name=${prayerTime.name}',
          );
          continue;
        }

        final minutesBefore = prayerSetting.minutesBefore;
        final scheduledDate = prayerTime
            .dateTimeOn(dailyPrayerTimes.date)
            .subtract(Duration(minutes: minutesBefore));

        debugPrint(
          '[NOTIFICATION] Evaluating prayer reminder. '
          'name=${prayerTime.name}, time=${prayerTime.formattedTime}, '
          'minutesBefore=$minutesBefore, scheduledDate=$scheduledDate, '
          'now=$now',
        );

        if (scheduledDate.isBefore(now)) {
          debugPrint(
            '[NOTIFICATION] Prayer reminder skipped: scheduled time is past. '
            'name=${prayerTime.name}, scheduledDate=$scheduledDate',
          );
          continue;
        }

        final notificationId = _notificationId(
          dailyPrayerTimes.city,
          prayerTime,
        );
        final notificationDate = tz.TZDateTime.from(scheduledDate, tz.local);
        debugPrint(
          '[NOTIFICATION] Scheduling prayer reminder... '
          'id=$notificationId, name=${prayerTime.name}, '
          'scheduledFor=$notificationDate',
        );
        final attempt = await _schedulePrayerReminderWithFallback(
          notificationId: notificationId,
          dailyPrayerTimes: dailyPrayerTimes,
          prayerTime: prayerTime,
          notificationDate: notificationDate,
          minutesBefore: minutesBefore,
        );
        exactAlarmPermissionRequired =
            exactAlarmPermissionRequired ||
                attempt.exactAlarmPermissionRequired;

        if (!attempt.scheduled) {
          continue;
        }

        scheduledPrayerNotificationIds.add(notificationId);
        scheduledNotificationCount++;
        debugPrint(
          'Bildirim planlandı: '
          'vakit adı=${prayerTime.name}, '
          'vakit saati=${prayerTime.formattedTime}, '
          'bildirim zamanı=$notificationDate, '
          'notification id=$notificationId',
        );
      }

      if (scheduledNotificationCount == 0) {
        debugPrint('Bugün için planlanacak bildirim kalmadı');
      }
      debugPrint(
        '[NOTIFICATION] Prayer reminders scheduled count: '
        '$scheduledNotificationCount',
      );
      final fridayScheduleResult = await _scheduleFridayPrayerReminderIfNeeded(
        dailyPrayerTimes,
        minutesBefore: fridayReminderMinutesBefore,
      );
      exactAlarmPermissionRequired =
          exactAlarmPermissionRequired ||
              fridayScheduleResult.exactAlarmPermissionRequired;
      if (fridayScheduleResult.notificationId != null) {
        scheduledFridayNotificationIds.add(fridayScheduleResult.notificationId!);
      }
      if (fridayScheduleResult.scheduled) {
        scheduledFridayNotificationCount++;
      }

      await _saveTrackedPrayerNotificationIds(scheduledPrayerNotificationIds);
      await _saveTrackedFridayNotificationIds(scheduledFridayNotificationIds);
      debugPrint(
        '[NOTIFICATION] schedulePrayerReminders finished. '
        'prayerScheduled=$scheduledNotificationCount, '
        'fridayScheduled=$scheduledFridayNotificationCount, '
        'exactAlarmPermissionRequired=$exactAlarmPermissionRequired',
      );
      return NotificationScheduleResult(
        scheduledAny:
            scheduledNotificationCount > 0 || scheduledFridayNotificationCount > 0,
        exactAlarmPermissionRequired: exactAlarmPermissionRequired,
      );
    } catch (error, stackTrace) {
      debugPrint('Namaz bildirimleri planlanamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return NotificationScheduleResult(
        scheduledAny: false,
        exactAlarmPermissionRequired: _isExactAlarmPermissionError(error),
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

    await _cancelTrackedPrayerReminderNotifications();
    await _cancelTrackedFridayPrayerReminderNotifications();
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) {
      debugPrint('[NOTIFICATION] showTestNotification skipped: web.');
      return;
    }

    try {
      debugPrint('[NOTIFICATION] Showing immediate test notification...');
      if (!_isInitialized) {
        debugPrint('[NOTIFICATION] showTestNotification initializing service.');
        await initialize();
      }

      final notificationId = _nextTestNotificationId();
      debugPrint('[NOTIFICATION] Immediate test notification id=$notificationId');
      await _plugin.show(
        notificationId,
        'Ezan Vakti Test',
        'Bildirim sistemi çalışıyor.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_reminders',
            'Namaz Hatırlatmaları',
            channelDescription: 'Namaz vakitlerinden önce uyarı gönderir.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
      );
      debugPrint('[NOTIFICATION] Immediate test notification success.');
    } catch (error, stackTrace) {
      debugPrint('Test bildirimi gönderilemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool?> canScheduleExactAlarms() async {
    if (!_isAndroidPlatform) {
      debugPrint(
        '[NOTIFICATION] Exact alarm check skipped: not Android platform.',
      );
      return true;
    }

    try {
      debugPrint('[NOTIFICATION] Checking exact alarm permission...');
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin == null) {
        debugPrint(
          '[NOTIFICATION] Exact alarm check failed: Android plugin is null.',
        );
        return null;
      }

      final canSchedule = await androidPlugin.canScheduleExactNotifications();
      debugPrint(
        '[NOTIFICATION] Exact alarm permission result: $canSchedule',
      );
      return canSchedule;
    } catch (error, stackTrace) {
      debugPrint('Kesin alarm izni kontrol edilemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool?> openExactAlarmSettings() async {
    if (!_isAndroidPlatform) {
      debugPrint(
        '[NOTIFICATION] Exact alarm settings skipped: not Android platform.',
      );
      return true;
    }

    try {
      debugPrint('[NOTIFICATION] Opening exact alarm settings...');
      if (!_isInitialized) {
        await initialize();
      }

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final isGranted = await androidPlugin?.requestExactAlarmsPermission();
      debugPrint(
        '[NOTIFICATION] Kesin alarm izin ekranı açıldı, '
        'izin durumu: $isGranted',
      );
      return isGranted;
    } catch (error, stackTrace) {
      debugPrint('Kesin alarm izin ekranı açılamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<NotificationScheduleResult> scheduleTestNotificationAfterOneMinute()
      async {
    if (kIsWeb) {
      debugPrint(
        '[NOTIFICATION] scheduleTestNotificationAfterOneMinute skipped: web.',
      );
      return const NotificationScheduleResult(scheduledAny: false);
    }

    try {
      debugPrint('[NOTIFICATION] Scheduling test notification...');
      if (!_isInitialized) {
        debugPrint(
          '[NOTIFICATION] scheduleTestNotificationAfterOneMinute '
          'initializing service.',
        );
        await initialize();
      }
      await _prepareLocalTimezone();

      final notificationId = _nextTestNotificationId();
      final notificationDate =
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

      debugPrint('[NOTIFICATION] Scheduled for: $notificationDate');
      debugPrint('[NOTIFICATION] Test notification id=$notificationId');

      final attempt = await _scheduleTestNotificationWithFallback(
        notificationId: notificationId,
        notificationDate: notificationDate,
      );

      if (attempt.scheduled) {
        debugPrint(
          '[NOTIFICATION] Success. Planlı test bildirimi planlandı: '
          'zaman=$notificationDate, notification id=$notificationId',
        );
      } else {
        debugPrint(
          '[NOTIFICATION] Failed. Planlı test bildirimi planlanamadı: '
          'notification id=$notificationId',
        );
      }

      return NotificationScheduleResult(
        scheduledAny: attempt.scheduled,
        exactAlarmPermissionRequired: attempt.exactAlarmPermissionRequired,
      );
    } catch (error, stackTrace) {
      debugPrint('Planlı test bildirimi planlanamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return NotificationScheduleResult(
        scheduledAny: false,
        exactAlarmPermissionRequired: _isExactAlarmPermissionError(error),
      );
    }
  }

  Future<void> _prepareLocalTimezone() async {
    debugPrint('[NOTIFICATION] Preparing local timezone...');
    tz.initializeTimeZones();
    await _configureLocalTimezone();
    debugPrint('[NOTIFICATION] Local timezone ready: ${tz.local.name}');
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timezoneName = timezoneInfo is String
          ? timezoneInfo
          : timezoneInfo.name as String;
      debugPrint('[NOTIFICATION] Device timezone: $timezoneName');
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (error, stackTrace) {
      debugPrint('[NOTIFICATION] Timezone configuration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Varsayılan timezone ile devam edilir.
    }
  }

  Future<_ScheduleAttempt> _schedulePrayerReminderWithFallback({
    required int notificationId,
    required DailyPrayerTimes dailyPrayerTimes,
    required PrayerTime prayerTime,
    required tz.TZDateTime notificationDate,
    required int minutesBefore,
  }) async {
    var exactAlarmPermissionRequired = false;

    try {
      debugPrint(
        '[NOTIFICATION] Trying exact prayer reminder. '
        'id=$notificationId, name=${prayerTime.name}, '
        'scheduledFor=$notificationDate',
      );
      await _schedulePrayerReminder(
        notificationId: notificationId,
        dailyPrayerTimes: dailyPrayerTimes,
        prayerTime: prayerTime,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
        '[NOTIFICATION] Exact prayer reminder success. '
        'id=$notificationId',
      );
      return const _ScheduleAttempt(scheduled: true);
    } catch (error, stackTrace) {
      exactAlarmPermissionRequired = _isExactAlarmPermissionError(error);
      if (exactAlarmPermissionRequired) {
        debugPrint(exactAlarmPermissionMessage);
      }
      debugPrint(
        'Exact bildirim planlama hatası, inexact deneniyor: '
        '${prayerTime.name} ${prayerTime.formattedTime}, id=$notificationId, '
        'hata=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      debugPrint(
        '[NOTIFICATION] Trying inexact prayer reminder. '
        'id=$notificationId, name=${prayerTime.name}, '
        'scheduledFor=$notificationDate',
      );
      await _schedulePrayerReminder(
        notificationId: notificationId,
        dailyPrayerTimes: dailyPrayerTimes,
        prayerTime: prayerTime,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint(
        '[NOTIFICATION] Inexact prayer reminder success. '
        'id=$notificationId',
      );
      return _ScheduleAttempt(
        scheduled: true,
        exactAlarmPermissionRequired: exactAlarmPermissionRequired,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Inexact bildirim planlama da başarısız oldu: '
        '${prayerTime.name} ${prayerTime.formattedTime}, id=$notificationId, '
        'hata=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return _ScheduleAttempt(
        scheduled: false,
        exactAlarmPermissionRequired:
            exactAlarmPermissionRequired || _isExactAlarmPermissionError(error),
      );
    }
  }

  Future<void> _schedulePrayerReminder({
    required int notificationId,
    required DailyPrayerTimes dailyPrayerTimes,
    required PrayerTime prayerTime,
    required tz.TZDateTime notificationDate,
    required int minutesBefore,
    required AndroidScheduleMode androidScheduleMode,
  }) async {
    debugPrint(
      '[NOTIFICATION] zonedSchedule prayer reminder. '
      'id=$notificationId, title=${prayerTime.name} vakti yaklaşıyor, '
      'scheduledFor=$notificationDate, mode=$androidScheduleMode',
    );
    await _plugin.zonedSchedule(
      notificationId,
      '${prayerTime.name} vakti yaklaşıyor',
      '${dailyPrayerTimes.city} için ${prayerTime.formattedTime} vaktine '
          '$minutesBefore dakika kaldı.',
      notificationDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_reminders',
          'Namaz Hatırlatmaları',
          channelDescription: 'Namaz vakitlerinden önce uyarı gönderir.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: androidScheduleMode,
    );
    debugPrint('[NOTIFICATION] zonedSchedule prayer success. id=$notificationId');
  }

  Future<_FridayScheduleResult> _scheduleFridayPrayerReminderIfNeeded(
    DailyPrayerTimes dailyPrayerTimes, {
    required int minutesBefore,
  }) async {
    debugPrint(
      '[NOTIFICATION] Evaluating Friday reminder. '
      'city=${dailyPrayerTimes.city}, date=${dailyPrayerTimes.date}, '
      'minutesBefore=$minutesBefore',
    );

    if (minutesBefore <= 0) {
      debugPrint('Cuma hatırlatması planlanmadı: ayar kapalı.');
      return const _FridayScheduleResult(scheduled: false);
    }

    if (minutesBefore != 15 && minutesBefore != 30 && minutesBefore != 60) {
      debugPrint(
        'Cuma hatırlatması planlanmadı: geçersiz süre. '
        'dakika=$minutesBefore',
      );
      return const _FridayScheduleResult(scheduled: false);
    }

    if (dailyPrayerTimes.date.weekday != DateTime.friday) {
      debugPrint(
        'Cuma hatırlatması planlanmadı: bugün Cuma değil. '
        'tarih=${dailyPrayerTimes.date}',
      );
      return const _FridayScheduleResult(scheduled: false);
    }

    final dhuhrPrayerTime = _findPrayerTimeByName(dailyPrayerTimes, 'Öğle');
    if (dhuhrPrayerTime == null) {
      debugPrint('Cuma hatırlatması planlanmadı: Öğle vakti bulunamadı.');
      return const _FridayScheduleResult(scheduled: false);
    }

    final scheduledDate = dhuhrPrayerTime
        .dateTimeOn(dailyPrayerTimes.date)
        .subtract(Duration(minutes: minutesBefore));
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint(
        'Cuma hatırlatması planlanmadı: bildirim zamanı geçti. '
        'cuma saati=${dhuhrPrayerTime.formattedTime}, '
        'bildirim zamanı=$scheduledDate',
      );
      return const _FridayScheduleResult(scheduled: false);
    }

    final notificationId = _fridayNotificationId(
      dailyPrayerTimes.city,
      dailyPrayerTimes.date,
    );
    final notificationDate = tz.TZDateTime.from(scheduledDate, tz.local);
    debugPrint(
      '[NOTIFICATION] Scheduling Friday reminder... '
      'id=$notificationId, scheduledFor=$notificationDate',
    );
    final attempt = await _scheduleFridayPrayerReminderWithFallback(
      notificationId: notificationId,
      notificationDate: notificationDate,
      minutesBefore: minutesBefore,
    );

    if (attempt.scheduled) {
      debugPrint(
        'Cuma hatırlatması planlandı: '
        'şehir=${dailyPrayerTimes.city}, '
        'cuma saati=${dhuhrPrayerTime.formattedTime}, '
        'bildirim zamanı=$notificationDate, '
        'notification id=$notificationId',
      );
    } else {
      debugPrint(
        'Cuma hatırlatması planlanmadı: bildirim planlama başarısız. '
        'notification id=$notificationId',
      );
    }

    return _FridayScheduleResult(
      scheduled: attempt.scheduled,
      exactAlarmPermissionRequired: attempt.exactAlarmPermissionRequired,
      notificationId: attempt.scheduled ? notificationId : null,
    );
  }

  Future<_ScheduleAttempt> _scheduleFridayPrayerReminderWithFallback({
    required int notificationId,
    required tz.TZDateTime notificationDate,
    required int minutesBefore,
  }) async {
    var exactAlarmPermissionRequired = false;

    try {
      debugPrint(
        '[NOTIFICATION] Trying exact Friday reminder. '
        'id=$notificationId, scheduledFor=$notificationDate',
      );
      await _scheduleFridayPrayerReminder(
        notificationId: notificationId,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
        '[NOTIFICATION] Exact Friday reminder success. id=$notificationId',
      );
      return const _ScheduleAttempt(scheduled: true);
    } catch (error, stackTrace) {
      exactAlarmPermissionRequired = _isExactAlarmPermissionError(error);
      if (exactAlarmPermissionRequired) {
        debugPrint(exactAlarmPermissionMessage);
      }
      debugPrint(
        'Cuma hatırlatması exact ile planlanamadı, inexact deneniyor: '
        'id=$notificationId, hata=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      debugPrint(
        '[NOTIFICATION] Trying inexact Friday reminder. '
        'id=$notificationId, scheduledFor=$notificationDate',
      );
      await _scheduleFridayPrayerReminder(
        notificationId: notificationId,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint(
        '[NOTIFICATION] Inexact Friday reminder success. id=$notificationId',
      );
      return _ScheduleAttempt(
        scheduled: true,
        exactAlarmPermissionRequired: exactAlarmPermissionRequired,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Cuma hatırlatması inexact ile de planlanamadı: '
        'id=$notificationId, hata=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return _ScheduleAttempt(
        scheduled: false,
        exactAlarmPermissionRequired:
            exactAlarmPermissionRequired || _isExactAlarmPermissionError(error),
      );
    }
  }

  Future<void> _scheduleFridayPrayerReminder({
    required int notificationId,
    required tz.TZDateTime notificationDate,
    required int minutesBefore,
    required AndroidScheduleMode androidScheduleMode,
  }) async {
    debugPrint(
      '[NOTIFICATION] zonedSchedule Friday reminder. '
      'id=$notificationId, scheduledFor=$notificationDate, '
      'mode=$androidScheduleMode',
    );
    await _plugin.zonedSchedule(
      notificationId,
      '🕌 Cuma Namazı',
      'Cuma namazına $minutesBefore dakika kaldı.',
      notificationDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_reminders',
          'Namaz Hatırlatmaları',
          channelDescription: 'Namaz vakitlerinden önce uyarı gönderir.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: androidScheduleMode,
    );
    debugPrint('[NOTIFICATION] zonedSchedule Friday success. id=$notificationId');
  }

  Future<_ScheduleAttempt> _scheduleTestNotificationWithFallback({
    required int notificationId,
    required tz.TZDateTime notificationDate,
  }) async {
    var exactAlarmPermissionRequired = false;

    try {
      debugPrint(
        '[NOTIFICATION] Trying exact test notification. '
        'id=$notificationId, scheduledFor=$notificationDate',
      );
      await _scheduleTestNotification(
        notificationId: notificationId,
        notificationDate: notificationDate,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
        '[NOTIFICATION] Exact test notification success. id=$notificationId',
      );
      return const _ScheduleAttempt(scheduled: true);
    } catch (error, stackTrace) {
      exactAlarmPermissionRequired = _isExactAlarmPermissionError(error);
      if (exactAlarmPermissionRequired) {
        debugPrint(exactAlarmPermissionMessage);
      }
      debugPrint(
        'Planlı test bildirimi exact ile planlanamadı, '
        'inexact deneniyor: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      debugPrint(
        '[NOTIFICATION] Trying inexact test notification. '
        'id=$notificationId, scheduledFor=$notificationDate',
      );
      await _scheduleTestNotification(
        notificationId: notificationId,
        notificationDate: notificationDate,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint(
        '[NOTIFICATION] Inexact test notification success. id=$notificationId',
      );
      return _ScheduleAttempt(
        scheduled: true,
        exactAlarmPermissionRequired: exactAlarmPermissionRequired,
      );
    } catch (error, stackTrace) {
      debugPrint('Planlı test bildirimi inexact ile de planlanamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _ScheduleAttempt(
        scheduled: false,
        exactAlarmPermissionRequired:
            exactAlarmPermissionRequired || _isExactAlarmPermissionError(error),
      );
    }
  }

  Future<void> _scheduleTestNotification({
    required int notificationId,
    required tz.TZDateTime notificationDate,
    required AndroidScheduleMode androidScheduleMode,
  }) async {
    debugPrint(
      '[NOTIFICATION] zonedSchedule test notification. '
      'id=$notificationId, scheduledFor=$notificationDate, '
      'mode=$androidScheduleMode',
    );
    await _plugin.zonedSchedule(
      notificationId,
      'Planlı Test',
      'Zamanlanmış bildirim çalıştı.',
      notificationDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_reminders',
          'Namaz Hatırlatmaları',
          channelDescription: 'Namaz vakitlerinden önce uyarı gönderir.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: androidScheduleMode,
    );
    debugPrint('[NOTIFICATION] zonedSchedule test success. id=$notificationId');
  }

  Future<void> _requestRuntimePermissions() async {
    debugPrint(
      '[NOTIFICATION] Requesting runtime permissions. '
      'platform=$defaultTargetPlatform',
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      debugPrint('[NOTIFICATION] Requesting Android POST_NOTIFICATIONS...');
      final notificationPermissionGranted =
          await androidPlugin?.requestNotificationsPermission();
      debugPrint(
        '[NOTIFICATION] Android POST_NOTIFICATIONS result: '
        '$notificationPermissionGranted',
      );
    } catch (error, stackTrace) {
      debugPrint('Android bildirim izni istenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final canScheduleExactAlarmNotifications =
        await canScheduleExactAlarms();
    debugPrint(
      'Kesin alarm izni durumu: $canScheduleExactAlarmNotifications',
    );

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin
    >();
    try {
      debugPrint('[NOTIFICATION] Requesting iOS notification permissions...');
      final iosPermissionGranted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[NOTIFICATION] iOS notification permission result: '
        '$iosPermissionGranted',
      );
    } catch (error, stackTrace) {
      debugPrint('iOS bildirim izni istenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _cancelTrackedPrayerReminderNotifications() async {
    final notificationIds = await _readTrackedPrayerNotificationIds();
    if (notificationIds.isEmpty) {
      debugPrint('İptal edilecek namaz hatırlatma bildirimi yok.');
      return;
    }

    debugPrint(
      'Namaz hatırlatma bildirimleri iptal ediliyor: '
      '${notificationIds.length} kayıt.',
    );

    for (final notificationId in notificationIds) {
      try {
        await _plugin.cancel(notificationId);
        debugPrint(
          'Namaz hatırlatma bildirimi iptal edildi: id=$notificationId',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Namaz hatırlatma bildirimi iptal edilemedi: '
          'id=$notificationId, hata=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    await _saveTrackedPrayerNotificationIds(<int>{});
  }

  Future<void> _cancelTrackedFridayPrayerReminderNotifications() async {
    final notificationIds = await _readTrackedFridayNotificationIds();
    if (notificationIds.isEmpty) {
      debugPrint('İptal edilecek Cuma hatırlatma bildirimi yok.');
      return;
    }

    debugPrint(
      'Cuma hatırlatma bildirimleri iptal ediliyor: '
      '${notificationIds.length} kayıt.',
    );

    for (final notificationId in notificationIds) {
      try {
        await _plugin.cancel(notificationId);
        debugPrint(
          'Cuma hatırlatma bildirimi iptal edildi: id=$notificationId',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Cuma hatırlatma bildirimi iptal edilemedi: '
          'id=$notificationId, hata=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    await _saveTrackedFridayNotificationIds(<int>{});
  }

  Future<Set<int>> _readTrackedPrayerNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds =
        prefs.getStringList(_prayerNotificationIdsPrefsKey) ?? <String>[];
    final notificationIds = <int>{..._scheduledPrayerNotificationIds};

    for (final storedId in storedIds) {
      final notificationId = int.tryParse(storedId);
      if (notificationId != null) {
        notificationIds.add(notificationId);
      }
    }

    return notificationIds;
  }

  Future<Set<int>> _readTrackedFridayNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds =
        prefs.getStringList(_fridayNotificationIdsPrefsKey) ?? <String>[];
    final notificationIds = <int>{..._scheduledFridayNotificationIds};

    for (final storedId in storedIds) {
      final notificationId = int.tryParse(storedId);
      if (notificationId != null) {
        notificationIds.add(notificationId);
      }
    }

    return notificationIds;
  }

  Future<void> _saveTrackedPrayerNotificationIds(
    Set<int> notificationIds,
  ) async {
    _scheduledPrayerNotificationIds = <int>{...notificationIds};

    final prefs = await SharedPreferences.getInstance();
    if (notificationIds.isEmpty) {
      await prefs.remove(_prayerNotificationIdsPrefsKey);
      return;
    }

    await prefs.setStringList(
      _prayerNotificationIdsPrefsKey,
      notificationIds.map((notificationId) => notificationId.toString()).toList()
        ..sort(),
    );
  }

  Future<void> _saveTrackedFridayNotificationIds(
    Set<int> notificationIds,
  ) async {
    _scheduledFridayNotificationIds = <int>{...notificationIds};

    final prefs = await SharedPreferences.getInstance();
    if (notificationIds.isEmpty) {
      await prefs.remove(_fridayNotificationIdsPrefsKey);
      return;
    }

    await prefs.setStringList(
      _fridayNotificationIdsPrefsKey,
      notificationIds.map((notificationId) => notificationId.toString()).toList()
        ..sort(),
    );
  }

  int _notificationId(String city, PrayerTime prayerTime) {
    final hash =
        '${city}_${prayerTime.name}_${prayerTime.hour}_${prayerTime.minute}'
                .hashCode &
            0x7fffffff;
    return _prayerNotificationIdBase + hash % _prayerNotificationIdRange;
  }

  int _fridayNotificationId(String city, DateTime date) {
    final hash = '${city}_friday_${date.year}_${date.month}_${date.day}'
            .hashCode &
        0x7fffffff;
    return _fridayNotificationIdBase + hash % _fridayNotificationIdRange;
  }

  PrayerTime? _findPrayerTimeByName(
    DailyPrayerTimes dailyPrayerTimes,
    String prayerName,
  ) {
    for (final prayerTime in dailyPrayerTimes.prayerTimes) {
      if (prayerTime.name == prayerName) {
        return prayerTime;
      }
    }

    return null;
  }

  int _nextTestNotificationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _testNotificationIdBase + timestamp % _testNotificationIdRange;
  }

  bool get _isAndroidPlatform {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  bool _isExactAlarmPermissionError(Object error) {
    return error is PlatformException &&
            error.code == _exactAlarmPermissionErrorCode ||
        error.toString().contains(_exactAlarmPermissionErrorCode);
  }
}

class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.scheduledAny,
    this.exactAlarmPermissionRequired = false,
  });

  final bool scheduledAny;
  final bool exactAlarmPermissionRequired;

  String? get userMessage {
    if (exactAlarmPermissionRequired) {
      return NotificationService.exactAlarmPermissionMessage;
    }

    return null;
  }
}

class _ScheduleAttempt {
  const _ScheduleAttempt({
    required this.scheduled,
    this.exactAlarmPermissionRequired = false,
  });

  final bool scheduled;
  final bool exactAlarmPermissionRequired;
}

class _FridayScheduleResult {
  const _FridayScheduleResult({
    required this.scheduled,
    this.exactAlarmPermissionRequired = false,
    this.notificationId,
  });

  final bool scheduled;
  final bool exactAlarmPermissionRequired;
  final int? notificationId;
}
