import 'package:flutter/material.dart';

import '../../../data/models/daily_prayer_times.dart';
import '../../../data/models/prayer_time.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_settings_service.dart';

class FridayScreen extends StatefulWidget {
  const FridayScreen({
    super.key,
    required this.dailyPrayerTimes,
  });

  final DailyPrayerTimes dailyPrayerTimes;

  @override
  State<FridayScreen> createState() => _FridayScreenState();
}

class _FridayScreenState extends State<FridayScreen> {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final NotificationService _notificationService = NotificationService.instance;

  NotificationSettings _notificationSettings = NotificationSettings.defaults;
  bool _isLoading = true;
  bool _isSaving = false;

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
      _notificationSettings = settings;
      _isLoading = false;
    });
  }

  Future<void> _setReminderMinutes(int minutesBefore) async {
    if (minutesBefore ==
        _notificationSettings.fridayReminderMinutesBefore) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    NotificationScheduleResult? scheduleResult;
    try {
      await _settingsService.saveFridayReminderMinutesBefore(minutesBefore);
      final settings = await _settingsService.readSettings();
      scheduleResult = await _applyNotificationSettings(settings);

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationSettings = settings;
      });
    } catch (error, stackTrace) {
      debugPrint('Cuma hatırlatma ayarı kaydedilemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuma hatırlatma ayarı kaydedilemedi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }

    _showScheduleMessageIfNeeded(scheduleResult);
  }

  Future<NotificationScheduleResult?> _applyNotificationSettings(
    NotificationSettings settings,
  ) async {
    return _notificationService.schedulePrayerReminders(
      widget.dailyPrayerTimes,
      prayerSettings: settings.prayerSettings,
      fridayReminderMinutesBefore: settings.fridayReminderMinutesBefore,
    );
  }

  void _showScheduleMessageIfNeeded(NotificationScheduleResult? result) {
    if (!mounted) {
      return;
    }

    final message = result?.userMessage;
    if (message == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  PrayerTime? _findPrayerTimeByName(String prayerName) {
    for (final prayerTime in widget.dailyPrayerTimes.prayerTimes) {
      if (prayerTime.name == prayerName) {
        return prayerTime;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fridayPrayerTime = _findPrayerTimeByName('Öğle');

    return Scaffold(
      appBar: AppBar(title: const Text('Cuma Namazı')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FridayInfoCard(
                  city: widget.dailyPrayerTimes.city,
                  fridayTimeText: fridayPrayerTime?.formattedTime ?? '--:--',
                  reminderText: _fridayReminderStatusText(
                    _notificationSettings.fridayReminderMinutesBefore,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hatırlatma',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: RadioGroup<int>(
                    groupValue:
                        _notificationSettings.fridayReminderMinutesBefore,
                    onChanged: (value) {
                      if (_isSaving || value == null) {
                        return;
                      }

                      _setReminderMinutes(value);
                    },
                    child: Column(
                      children: [
                        for (final minutes in NotificationSettings
                            .allowedFridayReminderMinutes)
                          RadioListTile<int>(
                            title: Text(_fridayReminderOptionText(minutes)),
                            value: minutes,
                            selected: minutes ==
                                _notificationSettings
                                    .fridayReminderMinutesBefore,
                          ),
                      ],
                    ),
                  ),
                ),
                if (_isSaving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
    );
  }
}

class _FridayInfoCard extends StatelessWidget {
  const _FridayInfoCard({
    required this.city,
    required this.fridayTimeText,
    required this.reminderText,
  });

  final String city;
  final String fridayTimeText;
  final String reminderText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_available,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cuma Namazı',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _FridayInfoRow(
              label: 'Cuma saati',
              value: fridayTimeText,
            ),
            const Divider(height: 20),
            _FridayInfoRow(
              label: 'Hatırlatma durumu',
              value: reminderText,
            ),
          ],
        ),
      ),
    );
  }
}

class _FridayInfoRow extends StatelessWidget {
  const _FridayInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _fridayReminderStatusText(int minutesBefore) {
  if (minutesBefore == NotificationSettings.fridayReminderOff) {
    return 'Kapalı';
  }

  return '$minutesBefore dakika önce';
}

String _fridayReminderOptionText(int minutesBefore) {
  if (minutesBefore == NotificationSettings.fridayReminderOff) {
    return 'Kapalı';
  }

  return '$minutesBefore dakika önce';
}
