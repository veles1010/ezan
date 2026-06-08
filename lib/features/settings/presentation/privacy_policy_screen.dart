import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik Politikası')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ezan Vakti Gizlilik Politikası',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const _PolicyCard(
            children: [
              'Ezan Vakti, namaz vakitlerini göstermek, namaz vakti '
                  'hatırlatmaları göndermek ve kıble yönünü bulmaya yardımcı '
                  'olmak amacıyla geliştirilmiştir.',
              'Uygulama, namaz vakitlerini almak ve güncel bilgileri '
                  'göstermek için internet bağlantısı kullanır.',
              'Konum bilgisi yalnızca bulunduğunuz şehir veya ilçeye göre '
                  'namaz vakitlerini belirlemek ve kıble yönünü hesaplamak '
                  'için kullanılır. Konum bilginiz bu amaçlar dışında '
                  'kullanılmaz.',
              'Bildirim izni yalnızca namaz vakti hatırlatmaları ve kullanıcı '
                  'tarafından seçilen bildirimleri göndermek için kullanılır.',
              'Uygulamada reklam göstermek için Google AdMob hizmeti '
                  'kullanılabilir. Reklam hizmetleri, Google tarafından '
                  'belirlenen reklam ve gizlilik kurallarına tabidir.',
              'Ezan Vakti, kişisel verilerinizi satmaz. Uygulama hassas '
                  'kişisel verilerinizi ticari amaçlarla üçüncü taraflara '
                  'aktarmaz.',
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Bu politika, uygulamanın kullandığı izinler ve hizmetler hakkında '
            'kullanıcıyı bilgilendirmek için hazırlanmıştır.',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.children});

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
