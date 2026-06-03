import '../models/ramadan_prayer_day.dart';
import '../services/ramadan_prayer_times_api_service.dart';

class RamadanPrayerTimesRepository {
  RamadanPrayerTimesRepository({RamadanPrayerTimesApiService? apiService})
      : _apiService = apiService ?? RamadanPrayerTimesApiService();

  final RamadanPrayerTimesApiService _apiService;

  Future<List<RamadanPrayerDay>> getRamadanPrayerDays({
    required String city,
  }) {
    return _apiService.fetchRamadanPrayerDays(city: city);
  }
}
