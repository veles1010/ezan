import 'package:flutter/material.dart';

import '../../../data/models/daily_prayer_times.dart';
import '../../../data/repositories/api_prayer_times_repository.dart';

class PrayerCalendarScreen extends StatefulWidget {
  const PrayerCalendarScreen({
    super.key,
    required this.city,
  });

  final String city;

  @override
  State<PrayerCalendarScreen> createState() => _PrayerCalendarScreenState();
}

class _PrayerCalendarScreenState extends State<PrayerCalendarScreen> {
  final ApiPrayerTimesRepository _repository = ApiPrayerTimesRepository();

  late final Future<List<DailyPrayerTimes>> _calendarFuture;

  @override
  void initState() {
    super.initState();
    _calendarFuture = _repository.getThirtyDayPrayerTimes(
      city: widget.city,
      startDate: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Namaz Takvimi')),
      body: FutureBuilder<List<DailyPrayerTimes>>(
        future: _calendarFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Takvim yüklenirken bir hata oluştu.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final calendar = snapshot.data ?? <DailyPrayerTimes>[];
          if (calendar.isEmpty) {
            return const Center(child: Text('Takvim verisi bulunamadı.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: calendar.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CalendarHeader(
                  city: widget.city,
                  monthText: _formatMonthRange(calendar),
                );
              }

              return _PrayerCalendarCard(dailyPrayerTimes: calendar[index - 1]);
            },
          );
        },
      ),
    );
  }

  String _formatMonthRange(List<DailyPrayerTimes> calendar) {
    final firstDate = calendar.first.date;
    final lastDate = calendar.last.date;
    final firstMonth = _monthName(firstDate.month);
    final lastMonth = _monthName(lastDate.month);

    if (firstDate.year == lastDate.year && firstDate.month == lastDate.month) {
      return '$firstMonth ${firstDate.year}';
    }

    if (firstDate.year == lastDate.year) {
      return '$firstMonth - $lastMonth ${firstDate.year}';
    }

    return '$firstMonth ${firstDate.year} - $lastMonth ${lastDate.year}';
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.city,
    required this.monthText,
  });

  final String city;
  final String monthText;

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
          Text(monthText, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PrayerCalendarCard extends StatelessWidget {
  const _PrayerCalendarCard({required this.dailyPrayerTimes});

  final DailyPrayerTimes dailyPrayerTimes;

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
              _formatDate(dailyPrayerTimes.date),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _PrayerTimeLine(
              label: 'İmsak',
              time: _timeFor('İmsak'),
            ),
            _PrayerTimeLine(
              label: 'Güneş',
              time: _timeFor('Güneş'),
            ),
            _PrayerTimeLine(
              label: 'Öğle',
              time: _timeFor('Öğle'),
            ),
            _PrayerTimeLine(
              label: 'İkindi',
              time: _timeFor('İkindi'),
            ),
            _PrayerTimeLine(
              label: 'Akşam',
              time: _timeFor('Akşam'),
            ),
            _PrayerTimeLine(
              label: 'Yatsı',
              time: _timeFor('Yatsı'),
            ),
          ],
        ),
      ),
    );
  }

  String _timeFor(String name) {
    for (final prayerTime in dailyPrayerTimes.prayerTimes) {
      if (_normalize(prayerTime.name) == _normalize(name)) {
        return prayerTime.formattedTime;
      }
    }

    return '--:--';
  }
}

class _PrayerTimeLine extends StatelessWidget {
  const _PrayerTimeLine({
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

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}
