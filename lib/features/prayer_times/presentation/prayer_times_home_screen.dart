import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/banner_ad_widget.dart';
import '../../../data/models/daily_prayer_times.dart';
import '../../../data/models/prayer_time.dart';
import '../../../data/repositories/api_prayer_times_repository.dart';
import '../../../data/repositories/mock_prayer_times_repository.dart';
import '../../../data/repositories/prayer_times_repository.dart';
import '../../../data/services/home_screen_widget_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_settings_service.dart';
import '../../../data/services/selected_city_service.dart';
import '../../../data/turkey_cities_districts.dart';
import '../../city_selection/presentation/city_selection_screen.dart';
import '../../friday/presentation/friday_screen.dart';
import '../../prayer_calendar/presentation/prayer_calendar_screen.dart';
import '../../qibla/presentation/qibla_screen.dart';
import '../../ramadan/presentation/ramadan_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'widgets/prayer_time_card.dart';

class PrayerTimesHomeScreen extends StatefulWidget {
  const PrayerTimesHomeScreen({super.key});

  @override
  State<PrayerTimesHomeScreen> createState() => _PrayerTimesHomeScreenState();
}

class _PrayerTimesHomeScreenState extends State<PrayerTimesHomeScreen>
    with WidgetsBindingObserver {
  final PrayerTimesRepository _repository = ApiPrayerTimesRepository();
  final PrayerTimesRepository _fallbackRepository = MockPrayerTimesRepository();
  final SelectedCityService _selectedCityService = SelectedCityService();
  final LocationService _locationService = LocationService();
  final NotificationSettingsService _notificationSettingsService =
      NotificationSettingsService();
  final NotificationService _notificationService = NotificationService.instance;
  final HomeScreenWidgetService _homeScreenWidgetService =
      HomeScreenWidgetService();

  DailyPrayerTimes? _dailyPrayerTimes;
  String? _selectedCity;
  String? _errorText;
  bool _isLoading = true;
  Timer? _countdownTimer;
  NotificationSettings _notificationSettings = NotificationSettings.defaults;

  List<String> get _availableCities => _repository.availableCities;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCountdownTimer();
    _loadInitialData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _dailyPrayerTimes == null) {
        return;
      }

      setState(() {});
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final storedCity = await _selectedCityService.readSelectedCity();
      final hasStoredCity =
          storedCity != null && isSupportedTurkeyLocation(storedCity);
      final city = hasStoredCity
          ? storedCity
          : (_availableCities.contains('İstanbul')
              ? 'İstanbul'
              : _availableCities.first);
      await _loadCity(city: city, persistCity: !hasStoredCity);
    } catch (error, stackTrace) {
      debugPrint('İlk veriler yüklenirken hata: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCity({
    required String city,
    bool persistCity = true,
  }) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final date = DateTime.now();
      late final DailyPrayerTimes dailyPrayerTimes;

      try {
        dailyPrayerTimes = await _repository.getDailyPrayerTimes(
          city: city,
          date: date,
        );
      } catch (apiError, stackTrace) {
        debugPrint('API verisi alinamadi, mock veriye geciliyor: $apiError');
        debugPrintStack(stackTrace: stackTrace);
        dailyPrayerTimes = await _fallbackRepository.getDailyPrayerTimes(
          city: city,
          date: date,
        );
      }

      if (persistCity) {
        await _selectedCityService.saveSelectedCity(city);
      }
      unawaited(
        _homeScreenWidgetService.updatePrayerTimesWidgetFromSelectedCity(),
      );

      var notificationSettings = _notificationSettings;
      NotificationScheduleResult? notificationScheduleResult;
      try {
        notificationSettings =
            await _notificationSettingsService.readSettings();
        notificationScheduleResult = await _applyNotificationSettings(
          dailyPrayerTimes,
          notificationSettings,
        );
      } catch (notificationError, stackTrace) {
        debugPrint('Bildirim ayarlari uygulanirken hata: $notificationError');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCity = city;
        _dailyPrayerTimes = dailyPrayerTimes;
        _notificationSettings = notificationSettings;
        _isLoading = false;
      });
      _showExactAlarmPermissionMessageIfNeeded(notificationScheduleResult);
    } catch (error, stackTrace) {
      debugPrint('Şehir verisi yüklenirken hata: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<NotificationScheduleResult?> _applyNotificationSettings(
    DailyPrayerTimes dailyPrayerTimes,
    NotificationSettings notificationSettings,
  ) async {
    if (!notificationSettings.notificationsEnabled) {
      debugPrint(
        'Bildirimler kapalı: namaz ve Cuma hatırlatmaları planlanmadı.',
      );
      await _notificationService.cancelPrayerReminders();
      return null;
    }

    return _notificationService.schedulePrayerReminders(
      dailyPrayerTimes,
      minutesBefore: notificationSettings.minutesBefore,
      fridayReminderMinutesBefore:
          notificationSettings.fridayReminderMinutesBefore,
    );
  }

  void _showExactAlarmPermissionMessageIfNeeded(
    NotificationScheduleResult? result,
  ) {
    final message = result?.userMessage;
    if (message == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openCitySelection() async {
    final selectedCity = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CitySelectionScreen(
          currentCity: _selectedCity,
        ),
      ),
    );

    if (selectedCity == null || selectedCity == _selectedCity) {
      return;
    }

    await _loadCity(city: selectedCity);
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      final locationSelection =
          await _locationService.getLocationSelectionFromCoordinates(
        location,
      );
      if (locationSelection == null) {
        debugPrint('Konumdan il/ilçe bulunamadı, mevcut seçim korunuyor.');
        return;
      }

      await _loadCity(city: locationSelection.displayName);
    } catch (error, stackTrace) {
      debugPrint('Konumdan sehir alinamadi: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

    final dailyPrayerTimes = _dailyPrayerTimes;
    if (dailyPrayerTimes == null) {
      return;
    }

    final notificationSettings =
        await _notificationSettingsService.readSettings();
    final notificationScheduleResult = await _applyNotificationSettings(
      dailyPrayerTimes,
      notificationSettings,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = notificationSettings;
    });
    _showExactAlarmPermissionMessageIfNeeded(notificationScheduleResult);
  }

  Future<void> _openQibla() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const QiblaScreen()),
    );
  }

  Future<void> _openFriday() async {
    final dailyPrayerTimes = _dailyPrayerTimes;
    if (dailyPrayerTimes == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FridayScreen(dailyPrayerTimes: dailyPrayerTimes),
      ),
    );

    final notificationSettings =
        await _notificationSettingsService.readSettings();
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = notificationSettings;
    });
  }

  Future<void> _openPrayerCalendar() async {
    final city = _selectedCity ?? _dailyPrayerTimes?.city;
    if (city == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrayerCalendarScreen(city: city),
      ),
    );
  }

  Future<void> _openRamadan() async {
    final city = _selectedCity ?? _dailyPrayerTimes?.city;
    if (city == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RamadanScreen(city: city),
      ),
    );
  }

  Future<void> _shareTodayPrayerTimes() async {
    final dailyPrayerTimes = _dailyPrayerTimes;
    if (dailyPrayerTimes == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paylaşılacak namaz vakti bulunamadı.'),
        ),
      );
      return;
    }

    try {
      final renderObject = context.findRenderObject();
      final sharePositionOrigin = renderObject is RenderBox
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          text: _buildPrayerTimesShareText(dailyPrayerTimes),
          title: '${dailyPrayerTimes.city} Namaz Vakitleri',
          subject: '${dailyPrayerTimes.city} Namaz Vakitleri',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Namaz vakitleri paylaşılamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Namaz vakitleri paylaşılırken bir hata oluştu.'),
        ),
      );
    }
  }

  String _buildPrayerTimesShareText(DailyPrayerTimes dailyPrayerTimes) {
    final hijriDateText = dailyPrayerTimes.hijriDateText;

    return <String>[
      '${dailyPrayerTimes.city} Namaz Vakitleri',
      _formatDate(dailyPrayerTimes.date),
      if (hijriDateText != null && hijriDateText.isNotEmpty) hijriDateText,
      '',
      _formatPrayerShareLine(dailyPrayerTimes, 'İmsak'),
      _formatPrayerShareLine(dailyPrayerTimes, 'Güneş'),
      _formatPrayerShareLine(dailyPrayerTimes, 'Öğle'),
      _formatPrayerShareLine(dailyPrayerTimes, 'İkindi'),
      _formatPrayerShareLine(dailyPrayerTimes, 'Akşam'),
      _formatPrayerShareLine(dailyPrayerTimes, 'Yatsı'),
      '',
      'Ezan Vakti uygulaması ile paylaşıldı.',
    ].join('\n');
  }

  String _formatPrayerShareLine(
    DailyPrayerTimes dailyPrayerTimes,
    String prayerName,
  ) {
    for (final prayerTime in dailyPrayerTimes.prayerTimes) {
      if (prayerTime.name == prayerName) {
        return '$prayerName: ${prayerTime.formattedTime}';
      }
    }

    return '$prayerName: --:--';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailyPrayerTimes = _dailyPrayerTimes;
    final appBarDate = dailyPrayerTimes?.date ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 96,
        titleSpacing: 16,
        centerTitle: false,
        title: _HomeAppBarTitle(
          dateText: _formatAppBarDate(appBarDate),
          hijriDateText: dailyPrayerTimes?.hijriDateText,
        ),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          _QuickActionMenu(
            onCitySelectionPressed: _openCitySelection,
            onCurrentLocationPressed: _goToCurrentLocation,
            onQiblaPressed: _openQibla,
            onPrayerCalendarPressed: _openPrayerCalendar,
            onFridayPressed: _openFriday,
            onRamadanPressed: _openRamadan,
            onSharePressed: _shareTodayPrayerTimes,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(theme, dailyPrayerTimes),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, DailyPrayerTimes? dailyPrayerTimes) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null) {
      return Center(child: Text('Hata detayı: $_errorText'));
    }

    if (dailyPrayerTimes == null) {
      return const Center(child: Text('Gösterilecek veri bulunamadı.'));
    }

    final nextPrayerInfo = _findNextPrayerInfo(dailyPrayerTimes);
    final nextPrayer = nextPrayerInfo?.prayerTime;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeaderCard(
          city: dailyPrayerTimes.city,
          nextPrayerText: nextPrayer == null
              ? 'Bugün için vakit bulunamadı'
              : '${nextPrayer.name} - ${nextPrayer.formattedTime}',
          remainingTimeText: nextPrayerInfo == null
              ? 'Vakit bulunamadı'
              : _formatRemainingTime(nextPrayerInfo.dateTime),
        ),
        const SizedBox(height: 16),
        Text(
          'Günlük Namaz Vakitleri',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        for (var index = 0;
            index < dailyPrayerTimes.prayerTimes.length;
            index++) ...[
          PrayerTimeCard(
            prayerTime: dailyPrayerTimes.prayerTimes[index],
            isNextPrayer:
                dailyPrayerTimes.prayerTimes[index].name == nextPrayer?.name,
          ),
          if (index < dailyPrayerTimes.prayerTimes.length - 1)
            const SizedBox(height: 10),
        ],
      ],
    );
  }

  _NextPrayerInfo? _findNextPrayerInfo(DailyPrayerTimes dailyPrayerTimes) {
    if (dailyPrayerTimes.prayerTimes.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    for (final prayer in dailyPrayerTimes.prayerTimes) {
      final prayerDateTime = prayer.dateTimeOn(dailyPrayerTimes.date);
      if (prayerDateTime.isAfter(now)) {
        return _NextPrayerInfo(prayerTime: prayer, dateTime: prayerDateTime);
      }
    }

    final firstPrayer = dailyPrayerTimes.prayerTimes.first;
    final tomorrow = dailyPrayerTimes.date.add(const Duration(days: 1));
    return _NextPrayerInfo(
      prayerTime: firstPrayer,
      dateTime: firstPrayer.dateTimeOn(tomorrow),
    );
  }

  String _formatRemainingTime(DateTime targetDateTime) {
    final remaining = targetDateTime.difference(DateTime.now());
    if (remaining.inMinutes < 1) {
      return 'Namaz vakti geldi';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours saat $minutes dakika';
    }

    return '$minutes dakika';
  }

  String _formatAppBarDate(DateTime date) {
    const weekdays = <String>[
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    const months = <String>[
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '${date.day} $month $weekday';
  }

  String _formatDate(DateTime date) {
    const weekdays = <String>[
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    const months = <String>[
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }

}

class _NextPrayerInfo {
  const _NextPrayerInfo({
    required this.prayerTime,
    required this.dateTime,
  });

  final PrayerTime prayerTime;
  final DateTime dateTime;
}

class _HomeAppBarTitle extends StatelessWidget {
  const _HomeAppBarTitle({
    required this.dateText,
    required this.hijriDateText,
  });

  final String dateText;
  final String? hijriDateText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Ezan Vakti',
              maxLines: 1,
              style: textTheme.headlineLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hijriDateText ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionMenu extends StatelessWidget {
  const _QuickActionMenu({
    required this.onCitySelectionPressed,
    required this.onCurrentLocationPressed,
    required this.onQiblaPressed,
    required this.onPrayerCalendarPressed,
    required this.onFridayPressed,
    required this.onRamadanPressed,
    required this.onSharePressed,
  });

  final VoidCallback onCitySelectionPressed;
  final VoidCallback onCurrentLocationPressed;
  final VoidCallback onQiblaPressed;
  final VoidCallback onPrayerCalendarPressed;
  final VoidCallback onFridayPressed;
  final VoidCallback onRamadanPressed;
  final VoidCallback onSharePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SizedBox(
        height: 70,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  label: 'Şehir Seç',
                  icon: Icons.location_city,
                  onPressed: onCitySelectionPressed,
                ),
              ),
              Expanded(
                child: _QuickActionButton(
                  label: 'Konumum',
                  icon: Icons.my_location,
                  onPressed: onCurrentLocationPressed,
                ),
              ),
              Expanded(
                child: _QuickActionButton(
                  label: 'Kıble',
                  icon: Icons.explore,
                  onPressed: onQiblaPressed,
                ),
              ),
              Expanded(
                child: _QuickActionButton(
                  label: 'Takvim',
                  icon: Icons.calendar_month,
                  onPressed: onPrayerCalendarPressed,
                ),
              ),
              Expanded(
                child: _QuickActionButton(
                  label: 'Cuma',
                  icon: Icons.event_available,
                  onPressed: onFridayPressed,
                ),
              ),
              Expanded(
                child: _QuickActionButton(
                  label: 'Ramazan',
                  icon: Icons.nightlight_round,
                  onPressed: onRamadanPressed,
                ),
              ),
              Expanded(
                child: _QuickActionButton(
                  label: 'Paylaş',
                  icon: Icons.share,
                  onPressed: onSharePressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.city,
    required this.nextPrayerText,
    required this.remainingTimeText,
  });

  final String city;
  final String nextPrayerText;
  final String remainingTimeText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Card(
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final nextPrayerColumn = _HeaderCardInfoColumn(
                    label: 'Sıradaki vakit',
                    value: nextPrayerText,
                  );
                  final remainingTimeColumn = _HeaderCardInfoColumn(
                    label: 'Kalan süre',
                    value: remainingTimeText,
                  );

                  if (constraints.maxWidth < 280) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        nextPrayerColumn,
                        const SizedBox(height: 8),
                        remainingTimeColumn,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: nextPrayerColumn),
                      const SizedBox(width: 12),
                      Expanded(child: remainingTimeColumn),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCardInfoColumn extends StatelessWidget {
  const _HeaderCardInfoColumn({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
