import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

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
          if (kIsWeb) {
            return _QiblaContent(qiblaAngle: qiblaAngle);
          }

          final compassEvents = FlutterCompass.events;
          if (compassEvents == null) {
            return _QiblaContent(
              qiblaAngle: qiblaAngle,
              message: 'Bu cihazda pusula sensörü bulunamadı.',
            );
          }

          return StreamBuilder<CompassEvent>(
            stream: compassEvents,
            builder: (context, compassSnapshot) {
              if (compassSnapshot.hasError) {
                debugPrint('Pusula sensörü okunamadı: ${compassSnapshot.error}');
                return _QiblaContent(
                  qiblaAngle: qiblaAngle,
                  message: 'Bu cihazda pusula sensörü bulunamadı.',
                );
              }

              final deviceHeading = compassSnapshot.data?.heading;
              if (deviceHeading == null) {
                final message =
                    compassSnapshot.connectionState == ConnectionState.waiting
                        ? null
                        : 'Bu cihazda pusula sensörü bulunamadı.';
                return _QiblaContent(qiblaAngle: qiblaAngle, message: message);
              }

              final arrowRotation = qiblaAngle - deviceHeading;
              return _QiblaContent(
                qiblaAngle: qiblaAngle,
                arrowRotationDegrees: arrowRotation,
              );
            },
          );
        },
      ),
    );
  }
}

class _QiblaContent extends StatelessWidget {
  const _QiblaContent({
    required this.qiblaAngle,
    this.arrowRotationDegrees = 0,
    this.message,
  });

  final double qiblaAngle;
  final double arrowRotationDegrees;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: arrowRotationDegrees * math.pi / 180,
              child: Icon(
                Icons.navigation,
                size: 128,
                color: colorScheme.primary,
              ),
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
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
