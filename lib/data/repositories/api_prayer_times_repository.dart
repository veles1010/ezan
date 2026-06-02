import '../models/daily_prayer_times.dart';
import '../services/prayer_times_api_service.dart';
import 'prayer_times_repository.dart';

class ApiPrayerTimesRepository implements PrayerTimesRepository {
  ApiPrayerTimesRepository({PrayerTimesApiService? apiService})
      : _apiService = apiService ?? PrayerTimesApiService();

  static const List<String> _supportedCities = <String>[
    'Ankara',
    'Bursa',
    '\u0130stanbul',
    '\u0130zmir',
  ];

  final PrayerTimesApiService _apiService;

  @override
  List<String> get availableCities => List<String>.unmodifiable(
        _supportedCities,
      );

  @override
  Future<DailyPrayerTimes> getDailyPrayerTimes({
    required String city,
    required DateTime date,
  }) {
    return _apiService.fetchDailyPrayerTimes(city: city, date: date);
  }
}
