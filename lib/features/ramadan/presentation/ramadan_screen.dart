import 'package:flutter/material.dart';

import '../../../data/models/ramadan_prayer_day.dart';
import '../../../data/repositories/ramadan_prayer_times_repository.dart';

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({
    super.key,
    required this.city,
  });

  final String city;

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  final RamadanPrayerTimesRepository _repository =
      RamadanPrayerTimesRepository();

  late final Future<List<RamadanPrayerDay>> _ramadanFuture;

  @override
  void initState() {
    super.initState();
    _ramadanFuture = _repository.getRamadanPrayerDays(city: widget.city);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ramazan İmsakiyesi')),
      body: FutureBuilder<List<RamadanPrayerDay>>(
        future: _ramadanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ramazan imsakiyesi alınamadı. Lütfen daha sonra tekrar '
                  'deneyin.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final days = snapshot.data ?? <RamadanPrayerDay>[];
          if (days.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ramazan imsakiyesi verisi bulunamadı.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: days.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _RamadanHeader(city: widget.city);
              }

              return _RamadanDayCard(day: days[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _RamadanHeader extends StatelessWidget {
  const _RamadanHeader({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(city, style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Ramazan İmsakiyesi', style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _RamadanDayCard extends StatelessWidget {
  const _RamadanDayCard({required this.day});

  final RamadanPrayerDay day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.ramadanDay}. Gün',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(day.gregorianDate),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _RamadanTimeLine(label: 'İmsak', time: day.imsak),
            _RamadanTimeLine(label: 'İftar', time: day.aksam),
          ],
        ),
      ),
    );
  }
}

class _RamadanTimeLine extends StatelessWidget {
  const _RamadanTimeLine({
    required this.label,
    required this.time,
  });

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(time, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final weekday = _weekdayName(date.weekday);
  final month = _monthName(date.month);
  return '$weekday, ${date.day} $month ${date.year}';
}

String _weekdayName(int weekday) {
  const weekdays = <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  return weekdays[weekday - 1];
}

String _monthName(int month) {
  const months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  return months[month - 1];
}
