import 'package:shared_preferences/shared_preferences.dart';

class PrayerNotificationSetting {
  const PrayerNotificationSetting({
    required this.enabled,
    required this.minutesBefore,
  });

  final bool enabled;
  final int minutesBefore;

  PrayerNotificationSetting copyWith({
    bool? enabled,
    int? minutesBefore,
  }) {
    return PrayerNotificationSetting(
      enabled: enabled ?? this.enabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
    );
  }

  @override
  String toString() {
    return 'PrayerNotificationSetting('
        'enabled: $enabled, minutesBefore: $minutesBefore)';
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.prayerSettings,
    required this.fridayReminderMinutesBefore,
  });

  static const List<String> prayerNames = <String>[
    'İmsak',
    'Güneş',
    'Öğle',
    'İkindi',
    'Akşam',
    'Yatsı',
  ];

  static const int minPrayerReminderMinutes = 2;
  static const int maxPrayerReminderMinutes = 23 * 60 + 59;
  static const int defaultPrayerReminderMinutes = 10;
  static const PrayerNotificationSetting defaultPrayerSetting =
      PrayerNotificationSetting(
    enabled: true,
    minutesBefore: defaultPrayerReminderMinutes,
  );

  static const int fridayReminderOff = 0;
  static const List<int> allowedFridayReminderMinutes = <int>[
    fridayReminderOff,
    15,
    30,
    60,
  ];

  static const NotificationSettings defaults = NotificationSettings(
    prayerSettings: <String, PrayerNotificationSetting>{
      'İmsak': defaultPrayerSetting,
      'Güneş': defaultPrayerSetting,
      'Öğle': defaultPrayerSetting,
      'İkindi': defaultPrayerSetting,
      'Akşam': defaultPrayerSetting,
      'Yatsı': defaultPrayerSetting,
    },
    fridayReminderMinutesBefore: fridayReminderOff,
  );

  final Map<String, PrayerNotificationSetting> prayerSettings;
  final int fridayReminderMinutesBefore;

  bool get notificationsEnabled {
    return prayerSettings.values.any((setting) => setting.enabled);
  }

  int get minutesBefore {
    return defaultPrayerSetting.minutesBefore;
  }

  NotificationSettings copyWith({
    Map<String, PrayerNotificationSetting>? prayerSettings,
    int? fridayReminderMinutesBefore,
  }) {
    return NotificationSettings(
      prayerSettings: prayerSettings ?? this.prayerSettings,
      fridayReminderMinutesBefore:
          fridayReminderMinutesBefore ?? this.fridayReminderMinutesBefore,
    );
  }
}

class NotificationSettingsService {
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _minutesBeforeKey = 'notification_minutes_before';
  static const String _fridayReminderMinutesBeforeKey =
      'friday_reminder_minutes_before';
  static const Map<String, String> _prayerPreferenceSlugs = <String, String>{
    'İmsak': 'imsak',
    'Güneş': 'gunes',
    'Öğle': 'ogle',
    'İkindi': 'ikindi',
    'Akşam': 'aksam',
    'Yatsı': 'yatsi',
  };

  Future<NotificationSettings> readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final prayerSettings = <String, PrayerNotificationSetting>{};

    for (final prayerName in NotificationSettings.prayerNames) {
      final enabledKey = _prayerEnabledKey(prayerName);
      final minutesKey = _prayerMinutesBeforeKey(prayerName);
      final storedEnabled = prefs.getBool(enabledKey);
      final storedMinutes = prefs.getInt(minutesKey);
      final enabled =
          storedEnabled ?? NotificationSettings.defaultPrayerSetting.enabled;
      final minutesBefore = _normalizePrayerReminderMinutes(storedMinutes);

      if (storedEnabled == null) {
        await prefs.setBool(enabledKey, enabled);
      }
      if (storedMinutes != minutesBefore) {
        await prefs.setInt(minutesKey, minutesBefore);
      }

      prayerSettings[prayerName] = PrayerNotificationSetting(
        enabled: enabled,
        minutesBefore: minutesBefore,
      );
    }

    final fridayReminderMinutesBefore =
        prefs.getInt(_fridayReminderMinutesBeforeKey) ??
            NotificationSettings.defaults.fridayReminderMinutesBefore;

    return NotificationSettings(
      prayerSettings: prayerSettings,
      fridayReminderMinutesBefore:
          NotificationSettings.allowedFridayReminderMinutes.contains(
        fridayReminderMinutesBefore,
      )
              ? fridayReminderMinutesBefore
              : NotificationSettings.defaults.fridayReminderMinutesBefore,
    );
  }

  Future<void> saveNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);

    for (final prayerName in NotificationSettings.prayerNames) {
      await prefs.setBool(_prayerEnabledKey(prayerName), enabled);
    }
  }

  Future<void> saveMinutesBefore(int minutesBefore) async {
    final normalizedMinutes = _normalizePrayerReminderMinutes(minutesBefore);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minutesBeforeKey, normalizedMinutes);

    for (final prayerName in NotificationSettings.prayerNames) {
      await prefs.setInt(
        _prayerMinutesBeforeKey(prayerName),
        normalizedMinutes,
      );
    }
  }

  Future<void> savePrayerNotificationEnabled(
    String prayerName,
    bool enabled,
  ) async {
    if (!_isKnownPrayerName(prayerName)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prayerEnabledKey(prayerName), enabled);
  }

  Future<void> savePrayerNotificationMinutesBefore(
    String prayerName,
    int minutesBefore,
  ) async {
    if (!_isKnownPrayerName(prayerName)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prayerMinutesBeforeKey(prayerName),
      _normalizePrayerReminderMinutes(minutesBefore),
    );
  }

  Future<void> saveFridayReminderMinutesBefore(int minutesBefore) async {
    if (!NotificationSettings.allowedFridayReminderMinutes.contains(
      minutesBefore,
    )) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fridayReminderMinutesBeforeKey, minutesBefore);
  }

  bool _isKnownPrayerName(String prayerName) {
    return _prayerPreferenceSlugs.containsKey(prayerName);
  }

  String _prayerEnabledKey(String prayerName) {
    return 'notification_${_prayerPreferenceSlug(prayerName)}_enabled';
  }

  String _prayerMinutesBeforeKey(String prayerName) {
    return 'notification_${_prayerPreferenceSlug(prayerName)}_minutes_before';
  }

  String _prayerPreferenceSlug(String prayerName) {
    return _prayerPreferenceSlugs[prayerName] ?? prayerName;
  }

  int _normalizePrayerReminderMinutes(int? minutesBefore) {
    final minutes =
        minutesBefore ?? NotificationSettings.defaultPrayerReminderMinutes;
    if (minutes < NotificationSettings.minPrayerReminderMinutes ||
        minutes > NotificationSettings.maxPrayerReminderMinutes) {
      return NotificationSettings.defaultPrayerReminderMinutes;
    }

    return minutes;
  }
}
