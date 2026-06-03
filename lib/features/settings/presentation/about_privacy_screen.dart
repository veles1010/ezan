import 'package:flutter/material.dart';

class AboutPrivacyScreen extends StatelessWidget {
  const AboutPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Hakkında ve Gizlilik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ezan Vakti',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sürüm: 0.1.0',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          const _InfoCard(
            children: [
              'Bu uygulama, namaz vakitlerini göstermek, hatırlatmalar '
                  'göndermek ve kıble yönünü belirlemeye yardımcı olmak için '
                  'geliştirilmiştir.',
              'Namaz vakitleri çevrim içi servislerden sağlanır.',
              'Konum izni, yalnızca bulunduğunuz şehri ve kıble yönünü '
                  'belirlemek için kullanılır.',
              'Bildirim izni, yalnızca namaz vakti hatırlatmaları için '
                  'kullanılır.',
              'Reklamlar Google AdMob tarafından gösterilir.',
              'Bu uygulama hassas kişisel verilerinizi saklamaz.',
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<String> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Text(
                children[index],
                style: textTheme.bodyLarge,
              ),
              if (index != children.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
