import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';

class PrayerTimesApiService {
  PrayerTimesApiService({http.Client? client})
      : _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.aladhan.com/v1/timingsByCity';
  static const String _country = 'Turkey';
  static const String _method = '13';

  final http.Client _client;

  Future<DailyPrayerTimes> fetchDailyPrayerTimes({
    required String city,
    DateTime? date,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: <String, String>{
        'city': city,
        'country': _country,
        'method': _method,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw PrayerTimesApiException(
        'Aladhan API hata kodu: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const PrayerTimesApiException('Aladhan API cevabı geçersiz.');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const PrayerTimesApiException('Aladhan API veri alanı geçersiz.');
    }

    final timings = data['timings'];
    if (timings is! Map<String, dynamic>) {
      throw const PrayerTimesApiException('Aladhan API vakitleri geçersiz.');
    }

    return DailyPrayerTimes(
      city: city,
      date: date ?? _parseGregorianDate(data) ?? DateTime.now(),
      hijriDateText: _parseHijriDateText(data),
      prayerTimes: <PrayerTime>[
        _parsePrayerTime('İmsak', timings['Fajr']),
        _parsePrayerTime('Güneş', timings['Sunrise']),
        _parsePrayerTime('Öğle', timings['Dhuhr']),
        _parsePrayerTime('İkindi', timings['Asr']),
        _parsePrayerTime('Akşam', timings['Maghrib']),
        _parsePrayerTime('Yatsı', timings['Isha']),
      ],
    );
  }

  PrayerTime _parsePrayerTime(String name, Object? value) {
    if (value is! String) {
      throw PrayerTimesApiException('$name vakti eksik.');
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) {
      throw PrayerTimesApiException('$name vakti okunamadı.');
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);

    return PrayerTime(name: name, hour: hour, minute: minute);
  }

  DateTime? _parseGregorianDate(Map<String, dynamic> data) {
    final date = data['date'];
    if (date is! Map<String, dynamic>) {
      return null;
    }

    final gregorian = date['gregorian'];
    if (gregorian is! Map<String, dynamic>) {
      return null;
    }

    final value = gregorian['date'];
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

  String? _parseHijriDateText(Map<String, dynamic> data) {
    final date = data['date'];
    if (date is! Map<String, dynamic>) {
      return null;
    }

    final hijri = date['hijri'];
    if (hijri is! Map<String, dynamic>) {
      return null;
    }

    final day = _parseInt(hijri['day']);
    final year = _parseInt(hijri['year']);
    final month = hijri['month'];
    if (month is! Map<String, dynamic>) {
      return null;
    }

    final monthNumber = _parseInt(month['number']);
    if (day == null || year == null || monthNumber == null) {
      return null;
    }

    const monthNames = <int, String>{
      1: 'Muharrem',
      2: 'Safer',
      3: 'Rebiülevvel',
      4: 'Rebiülahir',
      5: 'Cemaziyelevvel',
      6: 'Cemaziyelahir',
      7: 'Recep',
      8: 'Şaban',
      9: 'Ramazan',
      10: 'Şevval',
      11: 'Zilkade',
      12: 'Zilhicce',
    };
    final monthName = monthNames[monthNumber];
    if (monthName == null) {
      return null;
    }

    return '$day $monthName $year';
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
}

class PrayerTimesApiException implements Exception {
  const PrayerTimesApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
