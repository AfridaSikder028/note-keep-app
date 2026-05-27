import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_keep_app/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteKeepApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
