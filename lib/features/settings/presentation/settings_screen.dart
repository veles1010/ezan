import 'package:flutter/material.dart';

import '../../../data/services/notification_settings_service.dart';
import '../../../data/services/theme_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final ThemeSettingsService _themeSettingsService =
      ThemeSettingsService.instance;

  bool _isLoading = true;
  bool _notificationsEnabled =
      NotificationSettings.defaults.notificationsEnabled;
  int _minutesBefore = NotificationSettings.defaults.minutesBefore;
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

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });
    await _themeSettingsService.saveThemeMode(themeMode);
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
              ],
            ),
    );
  }
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
