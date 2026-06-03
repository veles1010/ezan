import 'dart:math' as math;

import 'location_service.dart';

class QiblaService {
  QiblaService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  static const double meccaLatitude = 21.4225;
  static const double meccaLongitude = 39.8262;

  final LocationService _locationService;

  Future<double> getCurrentLocationQiblaAngle() async {
    final location = await _locationService.getCurrentLocation();
    return calculateQiblaAngle(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  double calculateQiblaAngle({
    required double latitude,
    required double longitude,
  }) {
    final userLatitude = _toRadians(latitude);
    final userLongitude = _toRadians(longitude);
    final kaabaLatitude = _toRadians(meccaLatitude);
    final kaabaLongitude = _toRadians(meccaLongitude);

    final longitudeDifference = kaabaLongitude - userLongitude;
    final y = math.sin(longitudeDifference);
    final x = math.cos(userLatitude) * math.tan(kaabaLatitude) -
        math.sin(userLatitude) * math.cos(longitudeDifference);
    final bearing = _toDegrees(math.atan2(y, x));

    return (bearing + 360) % 360;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _toDegrees(double radians) {
    return radians * 180 / math.pi;
  }
}
