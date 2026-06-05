import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';

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
      return;
    }

    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    await _prepareLocalTimezone();

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

  Future<NotificationScheduleResult> schedulePrayerReminders(
    DailyPrayerTimes dailyPrayerTimes, {
    required int minutesBefore,
    int fridayReminderMinutesBefore = 0,
  }) async {
    if (kIsWeb) {
      return const NotificationScheduleResult(scheduledAny: false);
    }

    try {
      if (!_isInitialized) {
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
        final scheduledDate = prayerTime
            .dateTimeOn(dailyPrayerTimes.date)
            .subtract(Duration(minutes: minutesBefore));

        if (scheduledDate.isBefore(now)) {
          continue;
        }

        final notificationId = _notificationId(
          dailyPrayerTimes.city,
          prayerTime,
        );
        final notificationDate = tz.TZDateTime.from(scheduledDate, tz.local);
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
      return;
    }

    try {
      if (!_isInitialized) {
        await initialize();
      }

      await _plugin.show(
        _nextTestNotificationId(),
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
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Test bildirimi gönderilemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool?> canScheduleExactAlarms() async {
    if (!_isAndroidPlatform) {
      return true;
    }

    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.canScheduleExactNotifications();
    } catch (error, stackTrace) {
      debugPrint('Kesin alarm izni kontrol edilemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool?> openExactAlarmSettings() async {
    if (!_isAndroidPlatform) {
      return true;
    }

    try {
      if (!_isInitialized) {
        await initialize();
      }

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final isGranted = await androidPlugin?.requestExactAlarmsPermission();
      debugPrint('Kesin alarm izin ekranı açıldı, izin durumu: $isGranted');
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
      return const NotificationScheduleResult(scheduledAny: false);
    }

    try {
      if (!_isInitialized) {
        await initialize();
      }
      await _prepareLocalTimezone();

      final notificationId = _nextTestNotificationId();
      final notificationDate =
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

      debugPrint('Planlı test bildirimi zamanı: $notificationDate');

      final attempt = await _scheduleTestNotificationWithFallback(
        notificationId: notificationId,
        notificationDate: notificationDate,
      );

      if (attempt.scheduled) {
        debugPrint(
          'Planlı test bildirimi planlandı: '
          'zaman=$notificationDate, notification id=$notificationId',
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
    tz.initializeTimeZones();
    await _configureLocalTimezone();
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

  Future<_ScheduleAttempt> _schedulePrayerReminderWithFallback({
    required int notificationId,
    required DailyPrayerTimes dailyPrayerTimes,
    required PrayerTime prayerTime,
    required tz.TZDateTime notificationDate,
    required int minutesBefore,
  }) async {
    var exactAlarmPermissionRequired = false;

    try {
      await _schedulePrayerReminder(
        notificationId: notificationId,
        dailyPrayerTimes: dailyPrayerTimes,
        prayerTime: prayerTime,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
      await _schedulePrayerReminder(
        notificationId: notificationId,
        dailyPrayerTimes: dailyPrayerTimes,
        prayerTime: prayerTime,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
  }) {
    return _plugin.zonedSchedule(
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
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: androidScheduleMode,
    );
  }

  Future<_FridayScheduleResult> _scheduleFridayPrayerReminderIfNeeded(
    DailyPrayerTimes dailyPrayerTimes, {
    required int minutesBefore,
  }) async {
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
      await _scheduleFridayPrayerReminder(
        notificationId: notificationId,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
      await _scheduleFridayPrayerReminder(
        notificationId: notificationId,
        notificationDate: notificationDate,
        minutesBefore: minutesBefore,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
  }) {
    return _plugin.zonedSchedule(
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
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: androidScheduleMode,
    );
  }

  Future<_ScheduleAttempt> _scheduleTestNotificationWithFallback({
    required int notificationId,
    required tz.TZDateTime notificationDate,
  }) async {
    var exactAlarmPermissionRequired = false;

    try {
      await _scheduleTestNotification(
        notificationId: notificationId,
        notificationDate: notificationDate,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
      await _scheduleTestNotification(
        notificationId: notificationId,
        notificationDate: notificationDate,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
  }) {
    return _plugin.zonedSchedule(
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
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: androidScheduleMode,
    );
  }

  Future<void> _requestRuntimePermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await androidPlugin?.requestNotificationsPermission();
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
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
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
