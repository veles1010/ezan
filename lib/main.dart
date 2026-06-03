import 'package:flutter/material.dart';

import 'app.dart';
import 'data/services/ad_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/theme_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeSettingsService.instance.loadThemeMode();
  await AdService.initialize();
  await NotificationService.instance.initialize();
  runApp(const EzanVaktiApp());
}
