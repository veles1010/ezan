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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 720;
          final isVeryCompact = constraints.maxHeight < 640;
          final horizontalPadding = constraints.maxWidth < 360 ? 14.0 : 18.0;
          final verticalPadding =
              isVeryCompact ? 8.0 : isCompact ? 10.0 : 16.0;
          final sectionGap = isVeryCompact ? 8.0 : isCompact ? 10.0 : 14.0;
          final compassSize =
              isVeryCompact ? 188.0 : isCompact ? 214.0 : 240.0;
          final cardPadding = isCompact ? 10.0 : 12.0;
          final dividerHeight = isCompact ? 10.0 : 14.0;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kıble Yönü',
                      textAlign: TextAlign.center,
                      style: (isCompact
                              ? textTheme.titleLarge
                              : textTheme.headlineSmall)
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: isVeryCompact ? 4 : 6),
                    _SelectedLocationLabel(
                      selectedLocation: selectedLocation,
                      compact: isCompact,
                    ),
                    SizedBox(height: sectionGap),
                    _QiblaCompass(
                      arrowRotationDegrees: arrowRotationDegrees,
                      deviceHeadingDegrees: deviceHeadingDegrees,
                      isAligned: isAligned,
                      dimension: compassSize,
                    ),
                    SizedBox(height: sectionGap),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          children: [
                            _QiblaInfoRow(
                              label: 'Kâbe yönü',
                              value: _formatDegreeText(qiblaAngle),
                              compact: isCompact,
                            ),
                            Divider(height: dividerHeight),
                            _QiblaInfoRow(
                              label: 'Mevcut yön',
                              value: deviceHeadingDegrees == null
                                  ? '--°'
                                  : _formatDegreeText(deviceHeadingDegrees!),
                              compact: isCompact,
                            ),
                            Divider(height: dividerHeight),
                            _QiblaInfoRow(
                              label: 'Kıbleye kalan açı',
                              value: remainingAngle == null
                                  ? '--°'
                                  : _formatRemainingDegreeText(remainingAngle),
                              valueColor: isAligned ? alignedColor : null,
                              compact: isCompact,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isAligned) ...[
                      SizedBox(height: isVeryCompact ? 6 : 8),
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
                      SizedBox(height: isVeryCompact ? 6 : 8),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: isVeryCompact ? 8 : 10),
                    _QiblaCalibrationInfo(compact: isCompact),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QiblaCalibrationInfo extends StatelessWidget {
  const _QiblaCalibrationInfo({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.all(compact ? 9 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: compact ? 16 : 18,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                'Kıble yönü telefonunuzun pusula sensörü kullanılarak '
                'hesaplanır. Daha doğru sonuç için telefonunuzu havada birkaç '
                'kez 8 şekli çizerek kalibre etmeyi deneyiniz.',
                style: (compact ? textTheme.labelSmall : textTheme.bodySmall)
                    ?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedLocationLabel extends StatelessWidget {
  const _SelectedLocationLabel({
    required this.selectedLocation,
    required this.compact,
  });

  final String selectedLocation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: compact ? 16 : 18,
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: compact ? 5 : 6),
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
    required this.deviceHeadingDegrees,
    required this.isAligned,
    required this.dimension,
  });

  final double arrowRotationDegrees;
  final double? deviceHeadingDegrees;
  final bool isAligned;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compassColor = isAligned ? Colors.green.shade700 : colorScheme.primary;
    final borderColor =
        isAligned ? Colors.green.shade700 : colorScheme.outlineVariant;
    final headingDegrees = deviceHeadingDegrees ?? 0;
    final compassRotation = -headingDegrees * math.pi / 180;
    final labelCounterRotation = headingDegrees * math.pi / 180;
    final labelInset = dimension * 0.055;
    final sideLabelInset = dimension * 0.07;
    final innerCircleSize = dimension * 0.58;
    final arrowSize = dimension * 0.43;

    return SizedBox.square(
      dimension: dimension,
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
          Transform.rotate(
            angle: compassRotation,
            child: SizedBox.square(
              dimension: dimension,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: labelInset,
                    child: _CompassDirectionLabel(
                      label: 'K',
                      rotation: labelCounterRotation,
                    ),
                  ),
                  Positioned(
                    right: sideLabelInset,
                    child: _CompassDirectionLabel(
                      label: 'D',
                      rotation: labelCounterRotation,
                    ),
                  ),
                  Positioned(
                    bottom: labelInset,
                    child: _CompassDirectionLabel(
                      label: 'G',
                      rotation: labelCounterRotation,
                    ),
                  ),
                  Positioned(
                    left: sideLabelInset,
                    child: _CompassDirectionLabel(
                      label: 'B',
                      rotation: labelCounterRotation,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: innerCircleSize,
            height: innerCircleSize,
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
              size: arrowSize,
              color: compassColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassDirectionLabel extends StatelessWidget {
  const _CompassDirectionLabel({
    required this.label,
    required this.rotation,
  });

  final String label;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Transform.rotate(
      angle: rotation,
      child: Text(
        label,
        style: textTheme.titleMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QiblaInfoRow extends StatelessWidget {
  const _QiblaInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.compact,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                ?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: (compact ? textTheme.titleSmall : textTheme.titleMedium)
              ?.copyWith(
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
