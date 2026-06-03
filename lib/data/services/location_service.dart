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
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
