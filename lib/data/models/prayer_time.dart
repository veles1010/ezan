class PrayerTime {
  const PrayerTime({
    required this.name,
    required this.hour,
    required this.minute,
  });

  final String name;
  final int hour;
  final int minute;

  String get formattedTime => '${_twoDigits(hour)}:${_twoDigits(minute)}';

  DateTime dateTimeOn(DateTime date) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
