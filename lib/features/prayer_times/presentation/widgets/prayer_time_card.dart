import 'package:flutter/material.dart';

import '../../../../data/models/prayer_time.dart';

class PrayerTimeCard extends StatelessWidget {
  const PrayerTimeCard({
    super.key,
    required this.prayerTime,
    required this.isNextPrayer,
  });

  final PrayerTime prayerTime;
  final bool isNextPrayer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final containerColor =
        isNextPrayer ? colorScheme.secondaryContainer : colorScheme.surface;

    return Card(
      color: containerColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isNextPrayer ? Icons.notifications_active : Icons.schedule,
              color: isNextPrayer
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                prayerTime.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              prayerTime.formattedTime,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
