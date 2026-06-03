import 'prayer_time.dart';

class DailyPrayerTimes {
  const DailyPrayerTimes({
    required this.city,
    required this.date,
    required this.prayerTimes,
    this.hijriDateText,
  });

  final String city;
  final DateTime date;
  final List<PrayerTime> prayerTimes;
  final String? hijriDateText;
}
