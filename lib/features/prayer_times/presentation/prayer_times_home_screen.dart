import 'package:flutter/material.dart';

import '../../../data/models/daily_prayer_times.dart';
import '../../../data/models/prayer_time.dart';
import '../../../data/repositories/api_prayer_times_repository.dart';
import '../../../data/repositories/mock_prayer_times_repository.dart';
import '../../../data/repositories/prayer_times_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_settings_service.dart';
import '../../../data/services/selected_city_service.dart';
import '../../city_selection/presentation/city_selection_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'widgets/prayer_time_card.dart';

class PrayerTimesHomeScreen extends StatefulWidget {
  const PrayerTimesHomeScreen({super.key});

  @override
  State<PrayerTimesHomeScreen> createState() => _PrayerTimesHomeScreenState();
}

class _PrayerTimesHomeScreenState extends State<PrayerTimesHomeScreen> {
  final PrayerTimesRepository _repository = ApiPrayerTimesRepository();
  final PrayerTimesRepository _fallbackRepository = MockPrayerTimesRepository();
  final SelectedCityService _selectedCityService = SelectedCityService();
  final LocationService _locationService = LocationService();
  final NotificationSettingsService _notificationSettingsService =
      NotificationSettingsService();
  final NotificationService _notificationService = NotificationService.instance;

  DailyPrayerTimes? _dailyPrayerTimes;
  String? _selectedCity;
  String? _errorText;
  bool _isLoading = true;
  NotificationSettings _notificationSettings = NotificationSettings.defaults;

  List<String> get _availableCities => _repository.availableCities;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final storedCity = await _selectedCityService.readSelectedCity();
      final hasStoredCity =
          storedCity != null && _availableCities.contains(storedCity);
      final city = hasStoredCity
          ? storedCity
          : (_availableCities.contains('Antalya')
              ? 'Antalya'
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
          cities: _availableCities,
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
      final cityName = await _locationService.getCityNameFromCoordinates(
        location,
      );
      if (cityName == null) {
        debugPrint('Konumdan şehir bulunamadı, mevcut şehir korunuyor.');
        return;
      }

      final city = _findSupportedCity(cityName);
      if (city == null) {
        debugPrint('$cityName desteklenmiyor, mevcut şehir korunuyor.');
        return;
      }

      await _loadCity(city: city);
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

  String? _findSupportedCity(String cityName) {
    final normalizedCityName = _normalizeCityName(cityName);

    for (final city in _availableCities) {
      final normalizedCity = _normalizeCityName(city);
      if (normalizedCityName == normalizedCity ||
          normalizedCityName.contains(normalizedCity) ||
          normalizedCity.contains(normalizedCityName)) {
        return city;
      }
    }

    return null;
  }

  String _normalizeCityName(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u0307', '')
        .replaceAll('\u00e7', 'c')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00fc', 'u')
        .replaceAll(' province', '')
        .replaceAll(' ili', '')
        .trim();
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
            tooltip: 'Ayarlar',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildContent(theme, dailyPrayerTimes),
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

    final nextPrayer = _findNextPrayer(dailyPrayerTimes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCard(
          city: dailyPrayerTimes.city,
          dateText: _formatDate(dailyPrayerTimes.date),
          nextPrayerText: nextPrayer == null
              ? 'Bugün için vakit bulunamadı'
              : '${nextPrayer.name} - ${nextPrayer.formattedTime}',
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

  PrayerTime? _findNextPrayer(DailyPrayerTimes dailyPrayerTimes) {
    final now = DateTime.now();
    for (final prayer in dailyPrayerTimes.prayerTimes) {
      if (prayer.dateTimeOn(dailyPrayerTimes.date).isAfter(now)) {
        return prayer;
      }
    }
    return null;
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.city,
    required this.dateText,
    required this.nextPrayerText,
    required this.notificationText,
  });

  final String city;
  final String dateText;
  final String nextPrayerText;
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
