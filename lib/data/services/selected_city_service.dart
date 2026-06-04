import 'package:shared_preferences/shared_preferences.dart';

import '../turkey_cities_districts.dart';

class SelectedCityService {
  static const String _cityKey = 'selected_city';
  static const String _provinceKey = 'selected_province';
  static const String _districtKey = 'selected_district';

  Future<String?> readSelectedCity() async {
    final location = await readSelectedLocation();
    if (location == null) {
      return null;
    }

    return location.displayName;
  }

  Future<TurkeyLocationSelection?> readSelectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final storedProvince = prefs.getString(_provinceKey);
    final storedDistrict = prefs.getString(_districtKey);

    if (storedProvince != null && storedProvince.isNotEmpty) {
      final location = TurkeyLocationSelection.tryParse(
        storedDistrict == null || storedDistrict.isEmpty
            ? storedProvince
            : '$storedProvince / $storedDistrict',
      );
      if (location != null) {
        return location;
      }
    }

    final storedCity = prefs.getString(_cityKey);
    if (storedCity == null) {
      return null;
    }

    return TurkeyLocationSelection.tryParse(storedCity);
  }

  Future<void> saveSelectedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final location = TurkeyLocationSelection.tryParse(city);
    if (location == null) {
      await prefs.setString(_cityKey, city);
      await prefs.remove(_provinceKey);
      await prefs.remove(_districtKey);
      return;
    }

    await _saveLocation(prefs, location);
  }

  Future<void> saveSelectedLocation(TurkeyLocationSelection location) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveLocation(prefs, location);
  }

  Future<void> _saveLocation(
    SharedPreferences prefs,
    TurkeyLocationSelection location,
  ) async {
    await prefs.setString(_cityKey, location.displayName);
    await prefs.setString(_provinceKey, location.province);
    final district = location.district;
    if (district == null || district.isEmpty) {
      await prefs.remove(_districtKey);
    } else {
      await prefs.setString(_districtKey, district);
    }
  }
}
