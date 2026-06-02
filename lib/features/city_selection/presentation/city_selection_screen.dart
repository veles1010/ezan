import 'package:flutter/material.dart';

class CitySelectionScreen extends StatelessWidget {
  const CitySelectionScreen({
    super.key,
    required this.cities,
    required this.currentCity,
  });

  final List<String> cities;
  final String? currentCity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şehir Seçimi')),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: cities.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final city = cities[index];
          final selected = city == currentCity;

          return ListTile(
            title: Text(city),
            trailing: selected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : const Icon(Icons.radio_button_unchecked),
            onTap: () => Navigator.of(context).pop(city),
          );
        },
      ),
    );
  }
}
