import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';
import '../turkey_cities_districts.dart';

class PrayerTimesApiService {
  PrayerTimesApiService({http.Client? client})
      : _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.aladhan.com/v1/timingsByCity';
  static const String _country = 'Turkey';
  static const String _method = '13';

  final http.Client _client;

  Future<DailyPrayerTimes> fetchDailyPrayerTimes({
    required String city,
    String? district,
    DateTime? date,
  }) async {
    final location = _resolveLocation(city: city, district: district);
    final uri = _buildTimingsUri(date: date, location: location);

    debugPrint('Aladhan API URL: $uri');
    debugPrint('Aladhan API secilen il: ${location.province}');
    debugPrint('Aladhan API secilen ilce: ${location.district ?? '-'}');

    final response = await _client.get(uri);
    debugPrint('Aladhan API statusCode: ${response.statusCode}');
    debugPrint('Aladhan API response body: ${response.body}');

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
      city: location.displayName,
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

  Future<List<DailyPrayerTimes>> fetchThirtyDayPrayerTimes({
    required String city,
    required DateTime startDate,
  }) async {
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    final prayerTimes = <DailyPrayerTimes>[];

    for (var dayOffset = 0; dayOffset < 30; dayOffset++) {
      final date = firstDay.add(Duration(days: dayOffset));
      prayerTimes.add(
        await fetchDailyPrayerTimes(city: city, date: date),
      );
    }

    return prayerTimes;
  }

  Uri _buildTimingsUri({
    required TurkeyLocationSelection location,
    DateTime? date,
  }) {
    final endpoint =
        date == null ? _baseUrl : '$_baseUrl/${_formatApiDate(date)}';
    final queryParameters = <String, String>{
      'city': location.apiCity,
      'country': _country,
      'method': _method,
    };

    final district = location.district;
    if (district != null && district.isNotEmpty) {
      queryParameters['state'] = location.province;
    }

    return Uri.parse('$endpoint?${_encodedQueryParameters(queryParameters)}');
  }

  TurkeyLocationSelection _resolveLocation({
    required String city,
    String? district,
  }) {
    if (district != null && district.isNotEmpty) {
      final location = TurkeyLocationSelection.tryParse('$city / $district');
      if (location != null) {
        return location;
      }

      return TurkeyLocationSelection(province: city, district: district);
    }

    return TurkeyLocationSelection.tryParse(city) ??
        TurkeyLocationSelection(province: city);
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

  String _formatApiDate(DateTime date) {
    return '${_twoDigits(date.day)}-${_twoDigits(date.month)}-${date.year}';
  }

  String _encodedQueryParameters(Map<String, String> queryParameters) {
    return queryParameters.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}='
              '${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
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

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class PrayerTimesApiException implements Exception {
  const PrayerTimesApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
