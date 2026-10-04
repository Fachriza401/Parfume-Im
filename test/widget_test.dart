import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Parfum IM smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Parfum IM'),
          ),
        ),
      ),
    );

    expect(find.text('Parfum IM'), findsOneWidget);
  });
}
