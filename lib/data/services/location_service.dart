import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
        final cityName = _firstNotEmpty(<String?>[
          placemark.administrativeArea,
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.name,
        ]);
        if (cityName != null) {
          return cityName;
        }
      }

      debugPrint('Geocoding sonucu şehir alanı içermiyor.');
      return null;
    } catch (error, stackTrace) {
      debugPrint('Konumdan şehir alınırken hata: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  String? _firstNotEmpty(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
