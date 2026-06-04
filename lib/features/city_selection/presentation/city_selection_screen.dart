import 'package:flutter/material.dart';

import '../../../data/services/favorite_cities_service.dart';
import '../../../data/turkey_cities_districts.dart';

class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({
    super.key,
    required this.currentCity,
  });

  final String? currentCity;

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  final FavoriteCitiesService _favoriteCitiesService = FavoriteCitiesService();

  String _query = '';
  Set<String> _favoriteCities = <String>{};
  TurkeyProvince? _selectedProvince;

  @override
  void initState() {
    super.initState();
    _loadFavoriteCities();
  }

  List<TurkeyProvince> get _filteredProvinces {
    final query = normalizeTurkeyLocationText(_query);
    final sortedProvinces = List<TurkeyProvince>.from(turkeyProvinces)
      ..sort((first, second) => first.name.compareTo(second.name));
    if (query.isEmpty) {
      return sortedProvinces;
    }

    return sortedProvinces
        .where(
          (province) => normalizeTurkeyLocationText(province.name)
              .contains(query),
        )
        .toList();
  }

  List<String> get _filteredDistricts {
    final province = _selectedProvince;
    if (province == null) {
      return <String>[];
    }

    final query = normalizeTurkeyLocationText(_query);
    final sortedDistricts = List<String>.from(province.districts)..sort();
    if (query.isEmpty) {
      return sortedDistricts;
    }

    return sortedDistricts
        .where(
          (district) => normalizeTurkeyLocationText(district).contains(query),
        )
        .toList();
  }

  List<String> get _filteredFavoriteDistricts {
    final province = _selectedProvince;
    if (province == null) {
      return <String>[];
    }

    return _filteredDistricts
        .where(
          (district) => _favoriteCities.contains(
            _displayNameFor(province: province.name, district: district),
          ),
        )
        .toList();
  }

  List<String> get _filteredRegularDistricts {
    final province = _selectedProvince;
    if (province == null) {
      return <String>[];
    }

    return _filteredDistricts
        .where(
          (district) => !_favoriteCities.contains(
            _displayNameFor(province: province.name, district: district),
          ),
        )
        .toList();
  }

  TurkeyLocationSelection? get _currentLocation {
    final currentCity = widget.currentCity;
    if (currentCity == null) {
      return null;
    }

    return TurkeyLocationSelection.tryParse(currentCity);
  }

  Future<void> _loadFavoriteCities() async {
    final favoriteCities = await _favoriteCitiesService.readFavoriteCities();
    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteCities = favoriteCities
          .where((city) => TurkeyLocationSelection.tryParse(city) != null)
          .toSet();
    });
  }

  Future<void> _toggleFavoriteCity(String displayName) async {
    final favoriteCities = Set<String>.from(_favoriteCities);
    if (favoriteCities.contains(displayName)) {
      favoriteCities.remove(displayName);
    } else {
      favoriteCities.add(displayName);
    }

    setState(() {
      _favoriteCities = favoriteCities;
    });
    await _favoriteCitiesService.saveFavoriteCities(favoriteCities.toList());
  }

  void _selectProvince(TurkeyProvince province) {
    setState(() {
      _selectedProvince = province;
      _query = '';
    });
  }

  void _clearSelectedProvince() {
    setState(() {
      _selectedProvince = null;
      _query = '';
    });
  }

  String _displayNameFor({
    required String province,
    required String district,
  }) {
    return TurkeyLocationSelection(
      province: province,
      district: district,
    ).displayName;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedProvince = _selectedProvince;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedProvince == null ? 'İl Seçimi' : selectedProvince.name),
        leading: selectedProvince == null
            ? null
            : IconButton(
                tooltip: 'İl listesine dön',
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSelectedProvince,
              ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: selectedProvince == null ? 'İl ara' : 'İlçe ara',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
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
            child: selectedProvince == null
                ? _ProvinceList(
                    provinces: _filteredProvinces,
                    currentLocation: _currentLocation,
                    colorScheme: colorScheme,
                    onProvinceSelected: _selectProvince,
                  )
                : _DistrictList(
                    province: selectedProvince,
                    favoriteDistricts: _filteredFavoriteDistricts,
                    regularDistricts: _filteredRegularDistricts,
                    currentLocation: _currentLocation,
                    favoriteCities: _favoriteCities,
                    colorScheme: colorScheme,
                    displayNameFor: _displayNameFor,
                    onDistrictSelected: (displayName) {
                      Navigator.of(context).pop(displayName);
                    },
                    onFavoritePressed: _toggleFavoriteCity,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProvinceList extends StatelessWidget {
  const _ProvinceList({
    required this.provinces,
    required this.currentLocation,
    required this.colorScheme,
    required this.onProvinceSelected,
  });

  final List<TurkeyProvince> provinces;
  final TurkeyLocationSelection? currentLocation;
  final ColorScheme colorScheme;
  final ValueChanged<TurkeyProvince> onProvinceSelected;

  @override
  Widget build(BuildContext context) {
    if (provinces.isEmpty) {
      return const Center(child: Text('İl bulunamadı.'));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        for (final province in provinces)
          ListTile(
            selected: province.name == currentLocation?.province,
            selectedColor: colorScheme.primary,
            selectedTileColor: colorScheme.primaryContainer,
            title: Text(province.name),
            subtitle: Text('${province.districts.length} ilçe'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onProvinceSelected(province),
          ),
      ],
    );
  }
}

class _DistrictList extends StatelessWidget {
  const _DistrictList({
    required this.province,
    required this.favoriteDistricts,
    required this.regularDistricts,
    required this.currentLocation,
    required this.favoriteCities,
    required this.colorScheme,
    required this.displayNameFor,
    required this.onDistrictSelected,
    required this.onFavoritePressed,
  });

  final TurkeyProvince province;
  final List<String> favoriteDistricts;
  final List<String> regularDistricts;
  final TurkeyLocationSelection? currentLocation;
  final Set<String> favoriteCities;
  final ColorScheme colorScheme;
  final String Function({
    required String province,
    required String district,
  }) displayNameFor;
  final ValueChanged<String> onDistrictSelected;
  final ValueChanged<String> onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final hasVisibleDistricts =
        favoriteDistricts.isNotEmpty || regularDistricts.isNotEmpty;

    if (!hasVisibleDistricts) {
      return const Center(child: Text('İlçe bulunamadı.'));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        if (favoriteDistricts.isNotEmpty) ...[
          const _SectionTitle(title: 'Favori İlçeler'),
          for (final district in favoriteDistricts)
            _DistrictTile(
              province: province.name,
              district: district,
              currentLocation: currentLocation,
              favorite: true,
              colorScheme: colorScheme,
              displayNameFor: displayNameFor,
              onTap: onDistrictSelected,
              onFavoritePressed: onFavoritePressed,
            ),
          const Divider(height: 16),
        ],
        if (regularDistricts.isNotEmpty) ...[
          if (favoriteDistricts.isNotEmpty)
            const _SectionTitle(title: 'Tüm İlçeler'),
          for (final district in regularDistricts)
            _DistrictTile(
              province: province.name,
              district: district,
              currentLocation: currentLocation,
              favorite: favoriteCities.contains(displayNameFor(
                province: province.name,
                district: district,
              )),
              colorScheme: colorScheme,
              displayNameFor: displayNameFor,
              onTap: onDistrictSelected,
              onFavoritePressed: onFavoritePressed,
            ),
        ],
      ],
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

class _DistrictTile extends StatelessWidget {
  const _DistrictTile({
    required this.province,
    required this.district,
    required this.currentLocation,
    required this.favorite,
    required this.colorScheme,
    required this.displayNameFor,
    required this.onTap,
    required this.onFavoritePressed,
  });

  final String province;
  final String district;
  final TurkeyLocationSelection? currentLocation;
  final bool favorite;
  final ColorScheme colorScheme;
  final String Function({
    required String province,
    required String district,
  }) displayNameFor;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final displayName = displayNameFor(province: province, district: district);
    final selected = currentLocation?.displayName == displayName;

    return ListTile(
      selected: selected,
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primaryContainer,
      leading: IconButton(
        tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
        onPressed: () => onFavoritePressed(displayName),
        icon: Icon(
          favorite ? Icons.star : Icons.star_border,
          color: favorite ? colorScheme.primary : colorScheme.outline,
        ),
      ),
      title: Text(district),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: colorScheme.primary,
            )
          : Icon(
              Icons.radio_button_unchecked,
              color: colorScheme.outline,
            ),
      onTap: () => onTap(displayName),
    );
  }
}
