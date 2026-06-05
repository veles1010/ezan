import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class NotificationSettings {
  const NotificationSettings({
    required this.notificationsEnabled,
    required this.minutesBefore,
    required this.fridayReminderMinutesBefore,
  });

  static const List<int> allowedReminderMinutes = <int>[5, 10, 15, 30];
  static const int fridayReminderOff = 0;
  static const List<int> allowedFridayReminderMinutes = <int>[
    fridayReminderOff,
    15,
    30,
    60,
  ];

  static const NotificationSettings defaults = NotificationSettings(
    notificationsEnabled: true,
    minutesBefore: AppConstants.reminderMinutesBefore,
    fridayReminderMinutesBefore: fridayReminderOff,
  );

  final bool notificationsEnabled;
  final int minutesBefore;
  final int fridayReminderMinutesBefore;

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    int? minutesBefore,
    int? fridayReminderMinutesBefore,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
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

  Future<NotificationSettings> readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final minutesBefore = prefs.getInt(_minutesBeforeKey) ??
        NotificationSettings.defaults.minutesBefore;
    final fridayReminderMinutesBefore =
        prefs.getInt(_fridayReminderMinutesBeforeKey) ??
            NotificationSettings.defaults.fridayReminderMinutesBefore;

    return NotificationSettings(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ??
          NotificationSettings.defaults.notificationsEnabled,
      minutesBefore:
          NotificationSettings.allowedReminderMinutes.contains(minutesBefore)
              ? minutesBefore
              : NotificationSettings.defaults.minutesBefore,
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
  }

  Future<void> saveMinutesBefore(int minutesBefore) async {
    if (!NotificationSettings.allowedReminderMinutes.contains(minutesBefore)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minutesBeforeKey, minutesBefore);
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
}
