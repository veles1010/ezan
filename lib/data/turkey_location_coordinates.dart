import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import 'turkey_cities_districts.dart';

class TurkeyLocationCoordinate {
  const TurkeyLocationCoordinate({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class TurkeyLocationCoordinateResolver {
  Future<TurkeyLocationCoordinate> resolve(
    TurkeyLocationSelection location,
  ) async {
    final registeredCoordinate = findRegisteredTurkeyLocationCoordinate(
      location,
    );
    if (registeredCoordinate != null) {
      return registeredCoordinate;
    }

    if (kIsWeb) {
      throw PrayerLocationCoordinateException(
        '${location.displayName} için kayıtlı koordinat bulunamadı.',
      );
    }

    return _resolveWithPlatformGeocoder(location);
  }

  Future<TurkeyLocationCoordinate> _resolveWithPlatformGeocoder(
    TurkeyLocationSelection location,
  ) async {
    try {
      final address = '${location.displayName}, Türkiye';
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) {
        throw PrayerLocationCoordinateException(
          '${location.displayName} için koordinat bulunamadı.',
        );
      }

      final resolvedLocation = locations.first;
      return TurkeyLocationCoordinate(
        latitude: resolvedLocation.latitude,
        longitude: resolvedLocation.longitude,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[PRAYER_TIMES] Koordinat geocoding ile çözülemedi: '
        '${location.displayName}, hata=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (error is PrayerLocationCoordinateException) {
        rethrow;
      }

      throw PrayerLocationCoordinateException(
        '${location.displayName} için koordinat çözülemedi.',
      );
    }
  }
}

TurkeyLocationCoordinate? findRegisteredTurkeyLocationCoordinate(
  TurkeyLocationSelection location,
) {
  final district = location.district;
  if (district != null && district.isNotEmpty) {
    return _registeredCoordinates[_coordinateKey(
      province: location.province,
      district: district,
    )];
  }

  return _registeredCoordinates[_coordinateKey(province: location.province)];
}

String _coordinateKey({
  required String province,
  String? district,
}) {
  final normalizedProvince = normalizeTurkeyLocationText(province);
  final normalizedDistrict =
      district == null ? '' : normalizeTurkeyLocationText(district);
  return normalizedDistrict.isEmpty
      ? normalizedProvince
      : '$normalizedProvince/$normalizedDistrict';
}

final Map<String, TurkeyLocationCoordinate> _registeredCoordinates =
    <String, TurkeyLocationCoordinate>{
  _coordinateKey(province: 'Ankara'): const TurkeyLocationCoordinate(
    latitude: 39.9208,
    longitude: 32.8541,
  ),
  _coordinateKey(province: 'Antalya'): const TurkeyLocationCoordinate(
    latitude: 36.8841,
    longitude: 30.7056,
  ),
  _coordinateKey(
    province: 'Antalya',
    district: 'Aksu',
  ): const TurkeyLocationCoordinate(
    latitude: 36.9539,
    longitude: 30.8478,
  ),
  _coordinateKey(
    province: 'Antalya',
    district: 'Alanya',
  ): const TurkeyLocationCoordinate(
    latitude: 36.5444,
    longitude: 31.9954,
  ),
  _coordinateKey(province: 'Bursa'): const TurkeyLocationCoordinate(
    latitude: 40.1826,
    longitude: 29.0665,
  ),
  _coordinateKey(province: 'İstanbul'): const TurkeyLocationCoordinate(
    latitude: 41.0082,
    longitude: 28.9784,
  ),
  _coordinateKey(province: 'İzmir'): const TurkeyLocationCoordinate(
    latitude: 38.4237,
    longitude: 27.1428,
  ),
};

class PrayerLocationCoordinateException implements Exception {
  const PrayerLocationCoordinateException(this.message);

  final String message;

  @override
  String toString() => message;
}
