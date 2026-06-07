import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/daily_prayer_times.dart';
import '../models/prayer_time.dart';
import '../turkey_location_coordinates.dart';
import '../turkey_cities_districts.dart';

class PrayerTimesApiService {
  PrayerTimesApiService({
    http.Client? client,
    TurkeyLocationCoordinateResolver? coordinateResolver,
  })  : _client = client ?? http.Client(),
        _coordinateResolver =
            coordinateResolver ?? TurkeyLocationCoordinateResolver();

  static const String _baseUrl = 'https://api.aladhan.com/v1/timings';
  static const String _method = '13';

  final http.Client _client;
  final TurkeyLocationCoordinateResolver _coordinateResolver;

  Future<DailyPrayerTimes> fetchDailyPrayerTimes({
    required String city,
    String? district,
    DateTime? date,
  }) async {
    final location = _resolveLocation(city: city, district: district);
    final coordinate = await _coordinateResolver.resolve(location);
    return _fetchDailyPrayerTimesForResolvedLocation(
      location: location,
      coordinate: coordinate,
      date: date,
    );
  }

  Future<List<DailyPrayerTimes>> fetchThirtyDayPrayerTimes({
    required String city,
    required DateTime startDate,
  }) async {
    final location = _resolveLocation(city: city);
    final coordinate = await _coordinateResolver.resolve(location);
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    final prayerTimes = <DailyPrayerTimes>[];

    debugPrint(
      '[PRAYER_TIMES] 30 günlük takvim için koordinat çözüldü: '
      'displayName=${location.displayName}, '
      'latitude=${coordinate.latitude}, longitude=${coordinate.longitude}',
    );

    for (var dayOffset = 0; dayOffset < 30; dayOffset++) {
      final date = firstDay.add(Duration(days: dayOffset));
      prayerTimes.add(
        await _fetchDailyPrayerTimesForResolvedLocationWithRetry(
          location: location,
          coordinate: coordinate,
          date: date,
        ),
      );
    }

    return prayerTimes;
  }

  Future<DailyPrayerTimes> _fetchDailyPrayerTimesForResolvedLocation({
    required TurkeyLocationSelection location,
    required TurkeyLocationCoordinate coordinate,
    DateTime? date,
  }) async {
    final uri = _buildTimingsUri(
      date: date,
      coordinate: coordinate,
    );

    _debugPrintPrayerTimesInput(
      location: location,
      coordinate: coordinate,
      date: date,
      uri: uri,
    );
    debugPrint('Aladhan API URL: $uri');
    debugPrint('Aladhan API secilen il: ${location.province}');
    debugPrint('Aladhan API secilen ilce: ${location.district ?? '-'}');
    debugPrint('Aladhan API latitude: ${coordinate.latitude}');
    debugPrint('Aladhan API longitude: ${coordinate.longitude}');

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

    _debugPrintAladhanMeta(data);

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

  Future<DailyPrayerTimes> _fetchDailyPrayerTimesForResolvedLocationWithRetry({
    required TurkeyLocationSelection location,
    required TurkeyLocationCoordinate coordinate,
    required DateTime date,
  }) async {
    try {
      return await _fetchDailyPrayerTimesForResolvedLocation(
        location: location,
        coordinate: coordinate,
        date: date,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[PRAYER_TIMES] Takvim günü yüklenemedi, tekrar deneniyor: '
        'date=${_formatApiDate(date)}, location=${location.displayName}, '
        'hata=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _fetchDailyPrayerTimesForResolvedLocation(
        location: location,
        coordinate: coordinate,
        date: date,
      );
    }
  }

  Uri _buildTimingsUri({
    required TurkeyLocationCoordinate coordinate,
    DateTime? date,
  }) {
    final apiDate = _formatApiDate(date ?? DateTime.now());
    final endpoint = '$_baseUrl/$apiDate';
    final queryParameters = <String, String>{
      'latitude': coordinate.latitude.toString(),
      'longitude': coordinate.longitude.toString(),
      'method': _method,
    };

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

  void _debugPrintPrayerTimesInput({
    required TurkeyLocationSelection location,
    required TurkeyLocationCoordinate coordinate,
    required Uri uri,
    DateTime? date,
  }) {
    debugPrint(
      '[PRAYER_TIMES] Input: '
      'displayName=${location.displayName}, '
      'province=${location.province}, '
      'district=${location.district ?? '-'}, '
      'latitude=${coordinate.latitude}, '
      'longitude=${coordinate.longitude}, '
      'method=$_method, '
      'date=${date == null ? 'today' : _formatApiDate(date)}, '
      'endpoint=$_baseUrl',
    );
    debugPrint(
      '[PRAYER_TIMES] Coordinate input: '
      'latitude=${coordinate.latitude}, longitude=${coordinate.longitude}',
    );
    debugPrint('[PRAYER_TIMES] Request URI: $uri');
  }

  void _debugPrintAladhanMeta(Map<String, dynamic> data) {
    final meta = data['meta'];
    if (meta is! Map<String, dynamic>) {
      debugPrint('[PRAYER_TIMES] Aladhan meta alanı yok.');
      return;
    }

    final method = meta['method'];
    Object? methodId;
    Object? methodName;
    if (method is Map<String, dynamic>) {
      methodId = method['id'];
      methodName = method['name'];
    }

    debugPrint(
      '[PRAYER_TIMES] Aladhan resolved meta: '
      'latitude=${meta['latitude']}, '
      'longitude=${meta['longitude']}, '
      'timezone=${meta['timezone']}, '
      'methodId=${methodId ?? '-'}, '
      'methodName=${methodName ?? '-'}',
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
