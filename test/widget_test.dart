import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic Flutter widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Gestalk'),
        ),
      ),
    );

    expect(find.text('Gestalk'), findsOneWidget);
  });
}
