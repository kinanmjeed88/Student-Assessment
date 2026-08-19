import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the Arabic RTL application root', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          key: ValueKey('root-rtl'),
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Text('سجل الطالب'),
          ),
        ),
      ),
    );

    expect(find.text('سجل الطالب'), findsOneWidget);
    expect(find.byKey(const ValueKey('root-rtl')), findsOneWidget);
  });
}
