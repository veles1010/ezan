import 'package:home_widget/home_widget.dart';

class HomeWidgetClient {
  const HomeWidgetClient();

  Future<void> saveWidgetData(String key, String value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  Future<void> updateWidget({required String qualifiedAndroidName}) async {
    await HomeWidget.updateWidget(
      qualifiedAndroidName: qualifiedAndroidName,
    );
  }
}
