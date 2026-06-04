import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../turkey_cities_districts.dart';

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class LocationService {
  Future<DeviceLocation> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceException('Konum servisi kapalı.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const LocationServiceException('Konum izni reddedildi.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw const LocationServiceException(
          'Konum izni kalıcı olarak reddedildi.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Konum alınırken hata: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const LocationServiceException('Konum alınamadı.');
    }
  }

  Future<String?> getCityNameFromCoordinates(DeviceLocation location) async {
    final locationSelection = await getLocationSelectionFromCoordinates(
      location,
    );
    return locationSelection?.displayName;
  }

  Future<TurkeyLocationSelection?> getLocationSelectionFromCoordinates(
    DeviceLocation location,
  ) async {
    try {
      if (kIsWeb) {
        return null;
      }

      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isEmpty) {
        debugPrint('Geocoding sonucu boş döndü.');
        return null;
      }

      for (final placemark in placemarks) {
        _debugPrintPlacemarkFields(placemark);

        final locationSelection = _matchTurkeyLocation(placemark);
        if (locationSelection != null) {
          return locationSelection;
        }
      }

      debugPrint('Geocoding sonucu il/ilçe alanı eşleşmedi.');
      return null;
    } catch (error, stackTrace) {
      debugPrint('Konumdan il/ilçe alınırken hata: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  TurkeyLocationSelection? _matchTurkeyLocation(Placemark placemark) {
    final province = _firstMatchedProvince(<String?>[
      placemark.administrativeArea,
      placemark.subAdministrativeArea,
      placemark.locality,
      placemark.subLocality,
      placemark.name,
    ]);
    if (province == null) {
      return null;
    }

    final district = _firstMatchedDistrict(
      province.name,
      <String?>[
        placemark.subAdministrativeArea,
        placemark.locality,
        placemark.subLocality,
        placemark.name,
      ],
    );

    return TurkeyLocationSelection(
      province: province.name,
      district: district,
    );
  }

  TurkeyProvince? _firstMatchedProvince(Iterable<String?> values) {
    for (final value in values) {
      final trimmedValue = _trimOrNull(value);
      if (trimmedValue == null) {
        continue;
      }

      final province = findTurkeyProvince(trimmedValue);
      if (province != null) {
        return province;
      }
    }

    return null;
  }

  String? _firstMatchedDistrict(
    String provinceName,
    Iterable<String?> values,
  ) {
    final normalizedProvinceName = normalizeTurkeyLocationText(provinceName);
    for (final value in values) {
      final trimmedValue = _trimOrNull(value);
      if (trimmedValue == null ||
          normalizeTurkeyLocationText(trimmedValue) == normalizedProvinceName) {
        continue;
      }

      final district = findTurkeyDistrictName(provinceName, trimmedValue);
      if (district != null) {
        return district;
      }
    }

    return null;
  }

  void _debugPrintPlacemarkFields(Placemark placemark) {
    debugPrint(
      'Geocoding alanları: '
      'locality=${placemark.locality}, '
      'subLocality=${placemark.subLocality}, '
      'subAdministrativeArea=${placemark.subAdministrativeArea}, '
      'administrativeArea=${placemark.administrativeArea}',
    );
  }

  String? _trimOrNull(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
