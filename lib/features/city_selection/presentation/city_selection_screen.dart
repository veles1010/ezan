import 'package:flutter/material.dart';

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
  String _query = '';

  List<String> get _filteredCities {
    final query = _normalize(_query.trim());
    if (query.isEmpty) {
      return widget.cities;
    }

    return widget.cities
        .where((city) => _normalize(city).contains(query))
        .toList();
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
    final filteredCities = _filteredCities;

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
            child: filteredCities.isEmpty
                ? const Center(child: Text('Şehir bulunamadı.'))
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: filteredCities.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final city = filteredCities[index];
                      final selected = city == widget.currentCity;

                      return ListTile(
                        selected: selected,
                        selectedColor: colorScheme.primary,
                        selectedTileColor: colorScheme.primaryContainer,
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
                        onTap: () => Navigator.of(context).pop(city),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
