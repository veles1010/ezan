import 'package:flutter/material.dart';

import '../../../data/services/notification_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();

  bool _isLoading = true;
  bool _notificationsEnabled =
      NotificationSettings.defaults.notificationsEnabled;
  int _minutesBefore = NotificationSettings.defaults.minutesBefore;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.readSettings();
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationsEnabled = settings.notificationsEnabled;
      _minutesBefore = settings.minutesBefore;
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
