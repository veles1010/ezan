import '../models/daily_prayer_times.dart';
import '../services/prayer_times_api_service.dart';
import '../turkey_cities_districts.dart';
import 'prayer_times_repository.dart';

class ApiPrayerTimesRepository implements PrayerTimesRepository {
  ApiPrayerTimesRepository({PrayerTimesApiService? apiService})
      : _apiService = apiService ?? PrayerTimesApiService();

  final PrayerTimesApiService _apiService;

  @override
  List<String> get availableCities => turkeyProvinceNames;

  @override
  Future<DailyPrayerTimes> getDailyPrayerTimes({
    required String city,
    required DateTime date,
  }) {
    return _apiService.fetchDailyPrayerTimes(city: city, date: date);
  }

  Future<List<DailyPrayerTimes>> getThirtyDayPrayerTimes({
    required String city,
    required DateTime startDate,
  }) {
    return _apiService.fetchThirtyDayPrayerTimes(
      city: city,
      startDate: startDate,
    );
  }
}
