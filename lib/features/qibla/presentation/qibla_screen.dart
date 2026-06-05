import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../data/services/selected_city_service.dart';
import '../../../data/services/qibla_service.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final QiblaService _qiblaService = QiblaService();
  final SelectedCityService _selectedCityService = SelectedCityService();

  late final Future<double> _qiblaAngleFuture;
  late final Future<String> _selectedLocationFuture;

  @override
  void initState() {
    super.initState();
    _qiblaAngleFuture = _qiblaService.getCurrentLocationQiblaAngle();
    _selectedLocationFuture = _readSelectedLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kıble')),
      body: FutureBuilder<String>(
        future: _selectedLocationFuture,
        builder: (context, locationSnapshot) {
          return _buildQiblaBody(
            locationSnapshot.data ?? 'Seçili yer bulunamadı',
          );
        },
      ),
    );
  }

  Widget _buildQiblaBody(String selectedLocation) {
    return FutureBuilder<double>(
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
          return _QiblaContent(
            qiblaAngle: qiblaAngle,
            selectedLocation: selectedLocation,
          );
        }

        final compassEvents = FlutterCompass.events;
        if (compassEvents == null) {
          return _QiblaContent(
            qiblaAngle: qiblaAngle,
            selectedLocation: selectedLocation,
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
                selectedLocation: selectedLocation,
                message: 'Bu cihazda pusula sensörü bulunamadı.',
              );
            }

            final deviceHeading = compassSnapshot.data?.heading;
            if (deviceHeading == null) {
              final message =
                  compassSnapshot.connectionState == ConnectionState.waiting
                      ? null
                      : 'Bu cihazda pusula sensörü bulunamadı.';
              return _QiblaContent(
                qiblaAngle: qiblaAngle,
                selectedLocation: selectedLocation,
                message: message,
              );
            }

            final normalizedHeading = _normalizeDegrees(deviceHeading);
            final arrowRotation = qiblaAngle - normalizedHeading;
            return _QiblaContent(
              qiblaAngle: qiblaAngle,
              selectedLocation: selectedLocation,
              deviceHeadingDegrees: normalizedHeading,
              arrowRotationDegrees: arrowRotation,
            );
          },
        );
      },
    );
  }

  Future<String> _readSelectedLocation() async {
    try {
      return await _selectedCityService.readSelectedCity() ??
          'Seçili yer bulunamadı';
    } catch (error, stackTrace) {
      debugPrint('Seçili yer okunamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 'Seçili yer bulunamadı';
    }
  }
}

class _QiblaContent extends StatelessWidget {
  const _QiblaContent({
    required this.qiblaAngle,
    required this.selectedLocation,
    this.deviceHeadingDegrees,
    this.arrowRotationDegrees = 0,
    this.message,
  });

  final double qiblaAngle;
  final String selectedLocation;
  final double? deviceHeadingDegrees;
  final double arrowRotationDegrees;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final remainingAngle = deviceHeadingDegrees == null
        ? null
        : _remainingQiblaAngle(qiblaAngle, deviceHeadingDegrees!);
    final isAligned = remainingAngle != null && remainingAngle <= 5;
    final alignedColor = Colors.green.shade700;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kıble Yönü',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SelectedLocationLabel(selectedLocation: selectedLocation),
                const SizedBox(height: 24),
                _QiblaCompass(
                  arrowRotationDegrees: arrowRotationDegrees,
                  isAligned: isAligned,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _QiblaInfoRow(
                          label: 'Kâbe yönü',
                          value: _formatDegreeText(qiblaAngle),
                        ),
                        const Divider(height: 18),
                        _QiblaInfoRow(
                          label: 'Mevcut yön',
                          value: deviceHeadingDegrees == null
                              ? '--°'
                              : _formatDegreeText(deviceHeadingDegrees!),
                        ),
                        const Divider(height: 18),
                        _QiblaInfoRow(
                          label: 'Kıbleye kalan açı',
                          value: remainingAngle == null
                              ? '--°'
                              : _formatRemainingDegreeText(remainingAngle),
                          valueColor: isAligned ? alignedColor : null,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isAligned) ...[
                  const SizedBox(height: 16),
                  Text(
                    '✓ Kıble yönündesiniz',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: alignedColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
        ),
      ),
    );
  }
}

class _SelectedLocationLabel extends StatelessWidget {
  const _SelectedLocationLabel({required this.selectedLocation});

  final String selectedLocation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              selectedLocation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblaCompass extends StatelessWidget {
  const _QiblaCompass({
    required this.arrowRotationDegrees,
    required this.isAligned,
  });

  final double arrowRotationDegrees;
  final bool isAligned;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compassColor = isAligned ? Colors.green.shade700 : colorScheme.primary;
    final borderColor =
        isAligned ? Colors.green.shade700 : colorScheme.outlineVariant;

    return SizedBox.square(
      dimension: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer,
              border: Border.all(color: borderColor, width: 2),
            ),
          ),
          Positioned(
            top: 14,
            child: _CompassDirectionLabel(label: 'K'),
          ),
          Positioned(
            right: 18,
            child: _CompassDirectionLabel(label: 'D'),
          ),
          Positioned(
            bottom: 14,
            child: _CompassDirectionLabel(label: 'G'),
          ),
          Positioned(
            left: 18,
            child: _CompassDirectionLabel(label: 'B'),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
          ),
          Transform.rotate(
            angle: arrowRotationDegrees * math.pi / 180,
            child: Icon(
              Icons.navigation,
              size: 112,
              color: compassColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassDirectionLabel extends StatelessWidget {
  const _CompassDirectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Text(
      label,
      style: textTheme.titleMedium?.copyWith(
        color: colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _QiblaInfoRow extends StatelessWidget {
  const _QiblaInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: valueColor ?? colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

double _normalizeDegrees(double degrees) {
  return (degrees % 360 + 360) % 360;
}

double _remainingQiblaAngle(double qiblaAngle, double deviceHeading) {
  final difference = (qiblaAngle - deviceHeading + 540) % 360 - 180;
  return difference.abs();
}

String _formatDegreeText(double degrees) {
  final roundedDegrees = _normalizeDegrees(degrees).round() % 360;
  return '$roundedDegrees°';
}

String _formatRemainingDegreeText(double degrees) {
  return '${degrees.round()}°';
}
