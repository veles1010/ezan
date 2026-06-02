import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';
import 'prayer_times_repository.dart';

class MockPrayerTimesRepository implements PrayerTimesRepository {
  static const Map<String, List<PrayerTime>> _mockSchedules =
      <String, List<PrayerTime>>{
    'İstanbul': <PrayerTime>[
      PrayerTime(name: 'İmsak', hour: 3, minute: 34),
      PrayerTime(name: 'Güneş', hour: 5, minute: 29),
      PrayerTime(name: 'Öğle', hour: 13, minute: 5),
      PrayerTime(name: 'İkindi', hour: 16, minute: 59),
      PrayerTime(name: 'Akşam', hour: 20, minute: 30),
      PrayerTime(name: 'Yatsı', hour: 22, minute: 17),
    ],
    'Ankara': <PrayerTime>[
      PrayerTime(name: 'İmsak', hour: 3, minute: 23),
      PrayerTime(name: 'Güneş', hour: 5, minute: 17),
      PrayerTime(name: 'Öğle', hour: 12, minute: 50),
      PrayerTime(name: 'İkindi', hour: 16, minute: 42),
      PrayerTime(name: 'Akşam', hour: 20, minute: 15),
      PrayerTime(name: 'Yatsı', hour: 21, minute: 59),
    ],
    'İzmir': <PrayerTime>[
      PrayerTime(name: 'İmsak', hour: 3, minute: 43),
      PrayerTime(name: 'Güneş', hour: 5, minute: 36),
      PrayerTime(name: 'Öğle', hour: 13, minute: 11),
      PrayerTime(name: 'İkindi', hour: 17, minute: 2),
      PrayerTime(name: 'Akşam', hour: 20, minute: 34),
      PrayerTime(name: 'Yatsı', hour: 22, minute: 18),
    ],
    'Bursa': <PrayerTime>[
      PrayerTime(name: 'İmsak', hour: 3, minute: 35),
      PrayerTime(name: 'Güneş', hour: 5, minute: 30),
      PrayerTime(name: 'Öğle', hour: 13, minute: 6),
      PrayerTime(name: 'İkindi', hour: 16, minute: 58),
      PrayerTime(name: 'Akşam', hour: 20, minute: 29),
      PrayerTime(name: 'Yatsı', hour: 22, minute: 15),
    ],
  };

  @override
  List<String> get availableCities => _mockSchedules.keys.toList()..sort();

  @override
  Future<DailyPrayerTimes> getDailyPrayerTimes({
    required String city,
    required DateTime date,
  }) async {
    final schedules = _mockSchedules[city] ?? _mockSchedules.values.first;
    return DailyPrayerTimes(city: city, date: date, prayerTimes: schedules);
  }
}
