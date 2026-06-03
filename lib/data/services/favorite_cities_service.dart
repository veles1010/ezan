import 'package:shared_preferences/shared_preferences.dart';

class FavoriteCitiesService {
  static const String _favoriteCitiesKey = 'favorite_cities';

  Future<List<String>> readFavoriteCities() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoriteCitiesKey) ?? <String>[];
  }

  Future<void> saveFavoriteCities(List<String> cities) async {
    final sortedCities = List<String>.from(cities)..sort();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteCitiesKey, sortedCities);
  }
}
