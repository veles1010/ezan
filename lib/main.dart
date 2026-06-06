import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/services/ad_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/theme_settings_service.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('[UNCAUGHT][FlutterError] ${details.exception}');
        debugPrint('${details.stack}');
      };

      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        debugPrint('[UNCAUGHT][PlatformDispatcher] $error');
        debugPrint('$stack');
        return true;
      };

      await ThemeSettingsService.instance.loadThemeMode();
      await AdService.initialize();
      await NotificationService.instance.initialize();
      runApp(const EzanVaktiApp());
    },
    (error, stack) {
      debugPrint('[UNCAUGHT][Zone] $error');
      debugPrint('$stack');
    },
  );
}
