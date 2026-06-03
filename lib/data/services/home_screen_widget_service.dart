import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class HomeScreenWidgetService {
  const HomeScreenWidgetService();

  static const String widgetTitleKey = 'widget_title';
  static const String widgetNextPrayerKey = 'widget_next_prayer';
  static const String androidWidgetProviderName =
      'com.example.ezan_vakti.PrayerTimesWidgetProvider';

  Future<void> updatePrayerTimesWidget({
    String title = 'Ezan Vakti',
    String nextPrayer = 'Sonraki vakit: Öğle 13:00',
  }) async {
    if (!_supportsAndroidHomeWidget) {
      return;
    }

    try {
      await HomeWidget.saveWidgetData<String>(widgetTitleKey, title);
      await HomeWidget.saveWidgetData<String>(widgetNextPrayerKey, nextPrayer);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidWidgetProviderName,
      );
    } catch (error, stackTrace) {
      debugPrint('Android ana ekran widget güncellenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool get _supportsAndroidHomeWidget {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }
}
