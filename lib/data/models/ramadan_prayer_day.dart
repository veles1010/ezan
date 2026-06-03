class RamadanPrayerDay {
  const RamadanPrayerDay({
    required this.ramadanDay,
    required this.gregorianDate,
    required this.imsak,
    required this.aksam,
  });

  final int ramadanDay;
  final DateTime gregorianDate;
  final String imsak;
  final String aksam;
}
