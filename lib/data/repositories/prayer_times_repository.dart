import '../models/daily_prayer_times.dart';

abstract class PrayerTimesRepository {
  List<String> get availableCities;

  Future<DailyPrayerTimes> getDailyPrayerTimes({
    required String city,
    required DateTime date,
  });
}
