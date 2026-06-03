import 'package:flutter/material.dart';

import '../../../data/services/qibla_service.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final QiblaService _qiblaService = QiblaService();

  late final Future<double> _qiblaAngleFuture;

  @override
  void initState() {
    super.initState();
    _qiblaAngleFuture = _qiblaService.getCurrentLocationQiblaAngle();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kıble')),
      body: FutureBuilder<double>(
        future: _qiblaAngleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kıble yönü hesaplanamadı. Konum iznini ve konum servisinin '
                  'açık olduğunu kontrol edin.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final qiblaAngle = snapshot.data!;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.navigation,
                    size: 128,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Kıble yönü',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${qiblaAngle.round()}°',
                    style: textTheme.displaySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
