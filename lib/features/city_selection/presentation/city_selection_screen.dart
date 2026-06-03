import 'package:flutter/material.dart';

import '../../../data/services/favorite_cities_service.dart';

class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({
    super.key,
    required this.cities,
    required this.currentCity,
  });

  final List<String> cities;
  final String? currentCity;

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  final FavoriteCitiesService _favoriteCitiesService = FavoriteCitiesService();

  String _query = '';
  Set<String> _favoriteCities = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFavoriteCities();
  }

  List<String> get _filteredCities {
    final query = _normalize(_query.trim());
    final sortedCities = List<String>.from(widget.cities)..sort();
    if (query.isEmpty) {
      return sortedCities;
    }

    return sortedCities
        .where((city) => _normalize(city).contains(query))
        .toList();
  }

  List<String> get _filteredFavoriteCities {
    return _filteredCities
        .where((city) => _favoriteCities.contains(city))
        .toList();
  }

  List<String> get _filteredRegularCities {
    return _filteredCities
        .where((city) => !_favoriteCities.contains(city))
        .toList();
  }

  Future<void> _loadFavoriteCities() async {
    final favoriteCities = await _favoriteCitiesService.readFavoriteCities();
    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteCities = favoriteCities
          .where((city) => widget.cities.contains(city))
          .toSet();
    });
  }

  Future<void> _toggleFavoriteCity(String city) async {
    final favoriteCities = Set<String>.from(_favoriteCities);
    if (favoriteCities.contains(city)) {
      favoriteCities.remove(city);
    } else {
      favoriteCities.add(city);
    }

    setState(() {
      _favoriteCities = favoriteCities;
    });
    await _favoriteCitiesService.saveFavoriteCities(favoriteCities.toList());
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u0307', '')
        .replaceAll('\u00e7', 'c')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00fc', 'u');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final favoriteCities = _filteredFavoriteCities;
    final regularCities = _filteredRegularCities;
    final hasVisibleCities = favoriteCities.isNotEmpty || regularCities.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Şehir Seçimi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Şehir ara',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
          Expanded(
            child: !hasVisibleCities
                ? const Center(child: Text('Şehir bulunamadı.'))
                : ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    children: [
                      if (favoriteCities.isNotEmpty) ...[
                        const _SectionTitle(title: 'Favori Şehirler'),
                        for (final city in favoriteCities)
                          _CityTile(
                            city: city,
                            selected: city == widget.currentCity,
                            favorite: true,
                            colorScheme: colorScheme,
                            onTap: () => Navigator.of(context).pop(city),
                            onFavoritePressed: () => _toggleFavoriteCity(city),
                          ),
                        const Divider(height: 16),
                      ],
                      if (regularCities.isNotEmpty) ...[
                        if (favoriteCities.isNotEmpty)
                          const _SectionTitle(title: 'Tüm Şehirler'),
                        for (final city in regularCities)
                          _CityTile(
                            city: city,
                            selected: city == widget.currentCity,
                            favorite: false,
                            colorScheme: colorScheme,
                            onTap: () => Navigator.of(context).pop(city),
                            onFavoritePressed: () => _toggleFavoriteCity(city),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.city,
    required this.selected,
    required this.favorite,
    required this.colorScheme,
    required this.onTap,
    required this.onFavoritePressed,
  });

  final String city;
  final bool selected;
  final bool favorite;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primaryContainer,
      leading: IconButton(
        tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
        onPressed: onFavoritePressed,
        icon: Icon(
          favorite ? Icons.star : Icons.star_border,
          color: favorite ? colorScheme.primary : colorScheme.outline,
        ),
      ),
      title: Text(city),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: colorScheme.primary,
            )
          : Icon(
              Icons.radio_button_unchecked,
              color: colorScheme.outline,
            ),
      onTap: onTap,
    );
  }
}
