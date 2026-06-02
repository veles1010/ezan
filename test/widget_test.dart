import 'package:flutter_test/flutter_test.dart';

import 'package:ezan_vakti/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EzanVaktiApp());
    await tester.pump();

    expect(find.byType(EzanVaktiApp), findsOneWidget);
  });
}
