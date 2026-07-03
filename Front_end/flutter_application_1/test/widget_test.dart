import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App launches splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProxiSearchApp());
    await tester.pump();
    expect(find.byType(ProxiSearchApp), findsOneWidget);
  });
}
