import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ramadan_prayer_day.dart';
import '../turkey_cities_districts.dart';

class RamadanPrayerTimesApiService {
  RamadanPrayerTimesApiService({http.Client? client})
      : _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.aladhan.com/v1';
  static const String _country = 'Turkey';
  static const String _method = '13';
  static const int _ramadanMonth = 9;

  final http.Client _client;

  Future<List<RamadanPrayerDay>> fetchRamadanPrayerDays({
    required String city,
    DateTime? date,
  }) async {
    final location = _resolveLocation(city);
    final hijriYear = await _fetchCurrentHijriYear(
      location: location,
      date: date,
    );
    final uri = Uri.parse(
      '$_baseUrl/hijriCalendarByCity/$hijriYear/$_ramadanMonth',
    ).replace(
      queryParameters: _cityQueryParameters(location),
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw RamadanPrayerTimesApiException(
        'Ramazan verisi alınamadı. Hata kodu: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RamadanPrayerTimesApiException(
        'Ramazan API cevabı geçersiz.',
      );
    }

    final data = decoded['data'];
    if (data is! List) {
      throw const RamadanPrayerTimesApiException(
        'Ramazan takvimi verisi bulunamadı.',
      );
    }

    final days = <RamadanPrayerDay>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final day = _parseRamadanDay(item);
        if (day != null) {
          days.add(day);
        }
      }
    }

    if (days.isEmpty) {
      throw const RamadanPrayerTimesApiException(
        'Ramazan takvimi verisi alınamadı.',
      );
    }

    return days;
  }

  Future<int> _fetchCurrentHijriYear({
    required TurkeyLocationSelection location,
    DateTime? date,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/timingsByCity/${_formatApiDate(date ?? DateTime.now())}',
    ).replace(
      queryParameters: _cityQueryParameters(location),
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw RamadanPrayerTimesApiException(
        'Hicri yıl alınamadı. Hata kodu: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RamadanPrayerTimesApiException(
        'Hicri yıl API cevabı geçersiz.',
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const RamadanPrayerTimesApiException(
        'Hicri yıl verisi geçersiz.',
      );
    }

    final dateData = data['date'];
    if (dateData is! Map<String, dynamic>) {
      throw const RamadanPrayerTimesApiException(
        'Hicri tarih verisi bulunamadı.',
      );
    }

    final hijri = dateData['hijri'];
    if (hijri is! Map<String, dynamic>) {
      throw const RamadanPrayerTimesApiException(
        'Hicri yıl verisi bulunamadı.',
      );
    }

    final year = _parseInt(hijri['year']);
    if (year == null) {
      throw const RamadanPrayerTimesApiException('Hicri yıl okunamadı.');
    }

    return year;
  }

  RamadanPrayerDay? _parseRamadanDay(Map<String, dynamic> data) {
    final timings = data['timings'];
    final dateData = data['date'];
    if (timings is! Map<String, dynamic> || dateData is! Map<String, dynamic>) {
      return null;
    }

    final hijri = dateData['hijri'];
    final gregorian = dateData['gregorian'];
    if (hijri is! Map<String, dynamic> ||
        gregorian is! Map<String, dynamic>) {
      return null;
    }

    final ramadanDay = _parseInt(hijri['day']);
    final gregorianDate = _parseGregorianDate(gregorian['date']);
    final imsak = _parseTime(timings['Fajr']);
    final aksam = _parseTime(timings['Maghrib']);

    if (ramadanDay == null ||
        gregorianDate == null ||
        imsak == null ||
        aksam == null) {
      return null;
    }

    return RamadanPrayerDay(
      ramadanDay: ramadanDay,
      gregorianDate: gregorianDate,
      imsak: imsak,
      aksam: aksam,
    );
  }

  DateTime? _parseGregorianDate(Object? value) {
    if (value is! String) {
      return null;
    }

    final parts = value.split('-');
    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  String? _parseTime(Object? value) {
    if (value is! String) {
      return null;
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) {
      return null;
    }

    return '${_twoDigits(int.parse(match.group(1)!))}:${match.group(2)!}';
  }

  int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  String _formatApiDate(DateTime date) {
    return '${_twoDigits(date.day)}-${_twoDigits(date.month)}-${date.year}';
  }

  TurkeyLocationSelection _resolveLocation(String city) {
    return TurkeyLocationSelection.tryParse(city) ??
        TurkeyLocationSelection(province: city);
  }

  Map<String, String> _cityQueryParameters(TurkeyLocationSelection location) {
    final queryParameters = <String, String>{
      'city': location.apiCity,
      'country': _country,
      'method': _method,
    };

    final district = location.district;
    if (district != null && district.isNotEmpty) {
      queryParameters['state'] = location.province;
    }

    return queryParameters;
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class RamadanPrayerTimesApiException implements Exception {
  const RamadanPrayerTimesApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
