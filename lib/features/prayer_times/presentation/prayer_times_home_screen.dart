import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/daily_prayer_times.dart';
import '../../../data/models/prayer_time.dart';
import '../../../data/repositories/api_prayer_times_repository.dart';
import '../../../data/repositories/mock_prayer_times_repository.dart';
import '../../../data/repositories/prayer_times_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/selected_city_service.dart';
import '../../city_selection/presentation/city_selection_screen.dart';
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
  final NotificationService _notificationService = NotificationService.instance;

  DailyPrayerTimes? _dailyPrayerTimes;
  String? _selectedCity;
  String? _errorText;
  bool _isLoading = true;

  List<String> get _availableCities => _fallbackRepository.availableCities;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final storedCity = await _selectedCityService.readSelectedCity();
      final city = storedCity ??
          (_availableCities.contains('İstanbul')
              ? 'İstanbul'
              : _availableCities.first);
      await _loadCity(city: city, persistCity: storedCity == null);
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

      await _notificationService.schedulePrayerReminders(
        dailyPrayerTimes,
        minutesBefore: AppConstants.reminderMinutesBefore,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCity = city;
        _dailyPrayerTimes = dailyPrayerTimes;
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
  });

  final String city;
  final String dateText;
  final String nextPrayerText;

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
              'Her vakitten ${AppConstants.reminderMinutesBefore} dakika önce '
              'bildirim planlanır.',
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
