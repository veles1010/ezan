import 'package:shared_preferences/shared_preferences.dart';

class SelectedCityService {
  static const String _cityKey = 'selected_city';

  Future<String?> readSelectedCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey);
  }

  Future<void> saveSelectedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
  }
}
