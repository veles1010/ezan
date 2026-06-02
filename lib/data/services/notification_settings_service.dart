import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class NotificationSettings {
  const NotificationSettings({
    required this.notificationsEnabled,
    required this.minutesBefore,
  });

  static const List<int> allowedReminderMinutes = <int>[5, 10, 15, 30];

  static const NotificationSettings defaults = NotificationSettings(
    notificationsEnabled: true,
    minutesBefore: AppConstants.reminderMinutesBefore,
  );

  final bool notificationsEnabled;
  final int minutesBefore;

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    int? minutesBefore,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
    );
  }
}

class NotificationSettingsService {
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _minutesBeforeKey = 'notification_minutes_before';

  Future<NotificationSettings> readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final minutesBefore = prefs.getInt(_minutesBeforeKey) ??
        NotificationSettings.defaults.minutesBefore;

    return NotificationSettings(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ??
          NotificationSettings.defaults.notificationsEnabled,
      minutesBefore:
          NotificationSettings.allowedReminderMinutes.contains(minutesBefore)
              ? minutesBefore
              : NotificationSettings.defaults.minutesBefore,
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
}
