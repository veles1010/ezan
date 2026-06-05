import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_settings_service.dart';
import '../../../data/services/theme_settings_service.dart';
import 'about_privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final NotificationService _notificationService = NotificationService.instance;
  final ThemeSettingsService _themeSettingsService =
      ThemeSettingsService.instance;

  bool _isLoading = true;
  bool _notificationsEnabled =
      NotificationSettings.defaults.notificationsEnabled;
  int _minutesBefore = NotificationSettings.defaults.minutesBefore;
  int _fridayReminderMinutesBefore =
      NotificationSettings.defaults.fridayReminderMinutesBefore;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.readSettings();
    final themeMode = await _themeSettingsService.readThemeMode();
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationsEnabled = settings.notificationsEnabled;
      _minutesBefore = settings.minutesBefore;
      _fridayReminderMinutesBefore = settings.fridayReminderMinutesBefore;
      _themeMode = themeMode;
      _isLoading = false;
    });
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() {
      _notificationsEnabled = enabled;
    });
    await _settingsService.saveNotificationsEnabled(enabled);
  }

  Future<void> _setMinutesBefore(int minutesBefore) async {
    setState(() {
      _minutesBefore = minutesBefore;
    });
    await _settingsService.saveMinutesBefore(minutesBefore);
  }

  Future<void> _setFridayReminderMinutesBefore(int minutesBefore) async {
    setState(() {
      _fridayReminderMinutesBefore = minutesBefore;
    });
    await _settingsService.saveFridayReminderMinutesBefore(minutesBefore);
  }

  Future<void> _sendTestNotification() async {
    await _notificationService.showTestNotification();
  }

  Future<void> _scheduleTestNotificationAfterOneMinute() async {
    final result =
        await _notificationService.scheduleTestNotificationAfterOneMinute();
    if (!mounted) {
      return;
    }

    _showNotificationScheduleMessage(result);
  }

  Future<void> _openExactAlarmSettings() async {
    if (!mounted) {
      return;
    }

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kesin alarm izni'),
        content: const Text(
          'Android 12 ve üzeri cihazlarda namaz hatırlatmalarının zamanında '
          'gelmesi için Kesin Alarm iznini açmanız gerekir. Açılan Android '
          'ayarında Ezan Vakti için izni etkinleştirin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ayarı aç'),
          ),
        ],
      ),
    );

    if (shouldOpen != true) {
      return;
    }

    final isGranted = await _notificationService.openExactAlarmSettings();
    if (!mounted) {
      return;
    }

    final message = isGranted == true
        ? 'Kesin Alarm izni açık görünüyor.'
        : NotificationService.exactAlarmPermissionMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showNotificationScheduleMessage(NotificationScheduleResult result) {
    final message = result.userMessage ??
        (result.scheduledAny
            ? '1 dakika sonrası için test bildirimi planlandı.'
            : 'Test bildirimi planlanamadı.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: result.exactAlarmPermissionRequired
            ? SnackBarAction(
                label: 'Aç',
                onPressed: () {
                  _openExactAlarmSettings();
                },
              )
            : null,
      ),
    );
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });
    await _themeSettingsService.saveThemeMode(themeMode);
  }

  Future<void> _openAboutPrivacy() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AboutPrivacyScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const _SectionTitle(title: 'Bildirimler'),
                SwitchListTile(
                  title: const Text('Bildirimler'),
                  subtitle: Text(_notificationsEnabled ? 'Açık' : 'Kapalı'),
                  value: _notificationsEnabled,
                  onChanged: _setNotificationsEnabled,
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Test bildirimi gönder'),
                  onTap: _sendTestNotification,
                ),
                ListTile(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: const Text('1 dakika sonra test bildirimi planla'),
                  onTap: _scheduleTestNotificationAfterOneMinute,
                ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  ListTile(
                    leading: const Icon(Icons.alarm_on_outlined),
                    title: const Text('Kesin alarm iznini aç'),
                    subtitle: const Text(
                      'Android 12+ cihazlarda zamanında bildirim için gerekli.',
                    ),
                    onTap: _openExactAlarmSettings,
                  ),
                const Divider(height: 24),
                const _SectionTitle(title: 'Bildirim süresi'),
                RadioGroup<int>(
                  groupValue: _minutesBefore,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _setMinutesBefore(value);
                  },
                  child: Column(
                    children: [
                      for (final minutes
                          in NotificationSettings.allowedReminderMinutes)
                        RadioListTile<int>(
                          title: Text('$minutes dakika önce'),
                          value: minutes,
                          selected: minutes == _minutesBefore,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                const _SectionTitle(title: 'Cuma Hatırlatmaları'),
                RadioGroup<int>(
                  groupValue: _fridayReminderMinutesBefore,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _setFridayReminderMinutesBefore(value);
                  },
                  child: Column(
                    children: [
                      for (final minutes in NotificationSettings
                          .allowedFridayReminderMinutes)
                        RadioListTile<int>(
                          title: Text(_fridayReminderTitle(minutes)),
                          value: minutes,
                          selected: minutes == _fridayReminderMinutesBefore,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                const _SectionTitle(title: 'Tema'),
                RadioGroup<ThemeMode>(
                  groupValue: _themeMode,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _setThemeMode(value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('Sistem varsayılanı'),
                        value: ThemeMode.system,
                        selected: _themeMode == ThemeMode.system,
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Açık tema'),
                        value: ThemeMode.light,
                        selected: _themeMode == ThemeMode.light,
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Koyu tema'),
                        value: ThemeMode.dark,
                        selected: _themeMode == ThemeMode.dark,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Hakkında ve Gizlilik'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openAboutPrivacy,
                ),
              ],
            ),
    );
  }
}

String _fridayReminderTitle(int minutesBefore) {
  if (minutesBefore == NotificationSettings.fridayReminderOff) {
    return 'Kapalı';
  }

  return '$minutesBefore dakika önce';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
