import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/models/daily_prayer_times.dart';
import '../../../data/repositories/api_prayer_times_repository.dart';
import '../../../data/repositories/mock_prayer_times_repository.dart';
import '../../../data/repositories/prayer_times_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_settings_service.dart';
import '../../../data/services/selected_city_service.dart';
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
  final SelectedCityService _selectedCityService = SelectedCityService();
  final PrayerTimesRepository _repository = ApiPrayerTimesRepository();
  final PrayerTimesRepository _fallbackRepository = MockPrayerTimesRepository();
  final ThemeSettingsService _themeSettingsService =
      ThemeSettingsService.instance;

  bool _isLoading = true;
  Map<String, PrayerNotificationSetting> _prayerSettings =
      NotificationSettings.defaults.prayerSettings;
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
      _prayerSettings = Map<String, PrayerNotificationSetting>.from(
        settings.prayerSettings,
      );
      _themeMode = themeMode;
      _isLoading = false;
    });
  }

  Future<void> _setPrayerNotificationEnabled(
    String prayerName,
    bool enabled,
  ) async {
    final currentSetting =
        _prayerSettings[prayerName] ?? NotificationSettings.defaultPrayerSetting;
    setState(() {
      _prayerSettings = Map<String, PrayerNotificationSetting>.from(
        _prayerSettings,
      )..[prayerName] = currentSetting.copyWith(enabled: enabled);
    });
    await _settingsService.savePrayerNotificationEnabled(prayerName, enabled);
    await _reschedulePrayerReminders(changedPrayerName: prayerName);
  }

  Future<void> _setPrayerNotificationMinutesBefore(
    String prayerName,
    int minutesBefore,
  ) async {
    final currentSetting =
        _prayerSettings[prayerName] ?? NotificationSettings.defaultPrayerSetting;
    setState(() {
      _prayerSettings = Map<String, PrayerNotificationSetting>.from(
        _prayerSettings,
      )..[prayerName] = currentSetting.copyWith(minutesBefore: minutesBefore);
    });
    await _settingsService.savePrayerNotificationMinutesBefore(
      prayerName,
      minutesBefore,
    );
    await _reschedulePrayerReminders(changedPrayerName: prayerName);
  }

  Future<void> _reschedulePrayerReminders({String? changedPrayerName}) async {
    if (kIsWeb) {
      return;
    }

    try {
      final dailyPrayerTimes = await _loadCurrentPrayerTimes();
      if (dailyPrayerTimes == null) {
        debugPrint(
          'Bildirimler yeniden planlanamadı: seçili şehir bulunamadı.',
        );
        return;
      }

      final settings = await _settingsService.readSettings();
      final result = await _notificationService.schedulePrayerReminders(
        dailyPrayerTimes,
        prayerSettings: settings.prayerSettings,
        fridayReminderMinutesBefore: settings.fridayReminderMinutesBefore,
        allowPastDuePrayerReminders: true,
        pastDuePrayerName: changedPrayerName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _prayerSettings = Map<String, PrayerNotificationSetting>.from(
          settings.prayerSettings,
        );
      });
      _showPrayerReminderScheduleMessageIfNeeded(result);
    } catch (error, stackTrace) {
      debugPrint('Bildirimler yeniden planlanamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<DailyPrayerTimes?> _loadCurrentPrayerTimes() async {
    final city = await _selectedCityService.readSelectedCity();
    if (city == null || city.isEmpty) {
      return null;
    }

    final date = DateTime.now();
    try {
      return await _repository.getDailyPrayerTimes(city: city, date: date);
    } catch (error, stackTrace) {
      debugPrint(
        'Bildirim yeniden planlama için API verisi alınamadı, mock veriye '
        'geçiliyor: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return _fallbackRepository.getDailyPrayerTimes(city: city, date: date);
    }
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

  void _showPrayerReminderScheduleMessageIfNeeded(
    NotificationScheduleResult result,
  ) {
    final message = result.userMessage;
    if (message == null) {
      return;
    }

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

  Future<void> _openDurationPicker(String prayerName) async {
    final setting =
        _prayerSettings[prayerName] ?? NotificationSettings.defaultPrayerSetting;
    final selectedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var selectedHour = setting.minutesBefore ~/ 60;
        var selectedMinute = setting.minutesBefore.remainder(60);

        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalMinutes = selectedHour * 60 + selectedMinute;
            final isValid =
                totalMinutes >= NotificationSettings.minPrayerReminderMinutes &&
                    totalMinutes <=
                        NotificationSettings.maxPrayerReminderMinutes;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$prayerName bildirim süresi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedHour,
                            decoration: const InputDecoration(
                              labelText: 'Saat',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (var hour = 0; hour <= 23; hour++)
                                DropdownMenuItem<int>(
                                  value: hour,
                                  child: Text('$hour saat'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setModalState(() {
                                selectedHour = value;
                                if (selectedHour == 0 && selectedMinute < 2) {
                                  selectedMinute = 2;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedMinute,
                            decoration: const InputDecoration(
                              labelText: 'Dakika',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (var minute = 0; minute <= 59; minute++)
                                DropdownMenuItem<int>(
                                  value: minute,
                                  child: Text('$minute dakika'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setModalState(() {
                                selectedMinute = value;
                                if (selectedHour == 0 && selectedMinute < 2) {
                                  selectedMinute = 2;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Minimum 0 saat 2 dakika, maksimum 23 saat 59 dakika.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: isValid
                            ? () {
                                Navigator.of(context).pop(totalMinutes);
                              }
                            : null,
                        child: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedMinutes == null) {
      return;
    }

    await _setPrayerNotificationMinutesBefore(prayerName, selectedMinutes);
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
                const _SectionTitle(title: 'Namaz vakti bildirimleri'),
                for (final prayerName in NotificationSettings.prayerNames)
                  _PrayerNotificationSettingsTile(
                    prayerName: prayerName,
                    setting: _prayerSettings[prayerName] ??
                        NotificationSettings.defaultPrayerSetting,
                    onEnabledChanged: (enabled) {
                      _setPrayerNotificationEnabled(prayerName, enabled);
                    },
                    onDurationTap: () {
                      _openDurationPicker(prayerName);
                    },
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

class _PrayerNotificationSettingsTile extends StatelessWidget {
  const _PrayerNotificationSettingsTile({
    required this.prayerName,
    required this.setting,
    required this.onEnabledChanged,
    required this.onDurationTap,
  });

  final String prayerName;
  final PrayerNotificationSetting setting;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDurationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(prayerName),
          subtitle: Text(setting.enabled ? 'Açık' : 'Kapalı'),
          value: setting.enabled,
          onChanged: onEnabledChanged,
        ),
        ListTile(
          contentPadding: const EdgeInsetsDirectional.only(
            start: 16,
            end: 24,
          ),
          title: const Text('Bildirim Süresi'),
          subtitle: Text(_formatReminderDuration(setting.minutesBefore)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onDurationTap,
        ),
        const Divider(height: 1),
      ],
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

String _formatReminderDuration(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes.remainder(60);
  return '$hours saat $minutes dakika';
}
