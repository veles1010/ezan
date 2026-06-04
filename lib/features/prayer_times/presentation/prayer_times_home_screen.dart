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
        _errorText = 'Veriler yüklenirken bir hata oluştu.';
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

      final notificationSettings =
          await _notificationSettingsService.readSettings();
      await _applyNotificationSettings(dailyPrayerTimes, notificationSettings);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCity = city;
        _dailyPrayerTimes = dailyPrayerTimes;
        _notificationSettings = notificationSettings;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Şehir verisi yüklenirken hata: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Veriler yüklenirken bir hata oluştu.';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyNotificationSettings(
    DailyPrayerTimes dailyPrayerTimes,
    NotificationSettings notificationSettings,
  ) async {
    if (!notificationSettings.notificationsEnabled) {
      await _notificationService.cancelPrayerReminders();
      return;
    }

    await _notificationService.schedulePrayerReminders(
      dailyPrayerTimes,
      minutesBefore: notificationSettings.minutesBefore,
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
    await _applyNotificationSettings(dailyPrayerTimes, notificationSettings);

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = notificationSettings;
    });
  }

  Future<void> _openQibla() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const QiblaScreen()),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ezan Vakitleri'),
        actions: [
          IconButton(
            tooltip: 'Şehir seç',
            onPressed: _openCitySelection,
            icon: const Icon(Icons.location_city),
          ),
          IconButton(
            tooltip: 'Konumuma git',
            onPressed: _goToCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'Kıble',
            onPressed: _openQibla,
            icon: const Icon(Icons.explore),
          ),
          IconButton(
            tooltip: 'Takvim',
            onPressed: _openPrayerCalendar,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: 'Ramazan',
            onPressed: _openRamadan,
            icon: const Icon(Icons.nightlight_round),
          ),
          IconButton(
            tooltip: 'Paylaş',
            onPressed: _shareTodayPrayerTimes,
            icon: const Icon(Icons.share),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
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
      return Center(child: Text(_errorText!));
    }

    if (dailyPrayerTimes == null) {
      return const Center(child: Text('Gösterilecek veri bulunamadı.'));
    }

    final nextPrayerInfo = _findNextPrayerInfo(dailyPrayerTimes);
    final nextPrayer = nextPrayerInfo?.prayerTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCard(
          city: dailyPrayerTimes.city,
          dateText: _formatDate(dailyPrayerTimes.date),
          hijriDateText: dailyPrayerTimes.hijriDateText,
          nextPrayerText: nextPrayer == null
              ? 'Bugün için vakit bulunamadı'
              : '${nextPrayer.name} - ${nextPrayer.formattedTime}',
          remainingTimeText: nextPrayerInfo == null
              ? '--:--:--'
              : _formatRemainingTime(nextPrayerInfo.dateTime),
          notificationText: _notificationSettings.notificationsEnabled
              ? 'Her vakitten ${_notificationSettings.minutesBefore} dakika '
                  'önce bildirim planlanır.'
              : 'Bildirimler kapalı.',
        ),
        const SizedBox(height: 16),
        Text(
          'Günlük Namaz Vakitleri',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: dailyPrayerTimes.prayerTimes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final prayer = dailyPrayerTimes.prayerTimes[index];
              return PrayerTimeCard(
                prayerTime: prayer,
                isNextPrayer: prayer.name == nextPrayer?.name,
              );
            },
          ),
        ),
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
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final hours = safeRemaining.inHours;
    final minutes = safeRemaining.inMinutes.remainder(60);
    final seconds = safeRemaining.inSeconds.remainder(60);
    return '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
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

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.city,
    required this.dateText,
    required this.hijriDateText,
    required this.nextPrayerText,
    required this.remainingTimeText,
    required this.notificationText,
  });

  final String city;
  final String dateText;
  final String? hijriDateText;
  final String nextPrayerText;
  final String remainingTimeText;
  final String notificationText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              city,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateText,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            if (hijriDateText != null && hijriDateText!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                hijriDateText!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Sıradaki vakit',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              nextPrayerText,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Kalan süre',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              remainingTimeText,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              notificationText,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
