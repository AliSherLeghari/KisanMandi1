import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisanmandi/app_store.dart';
import 'package:kisanmandi/onboarding.dart';

void main() {
  testWidgets('Onboarding displays required identity and role fields', (tester) async {
    final store = AppStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: Onboarding(store: store)));

    expect(find.text('Welcome to KisanMandi'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('District'), findsOneWidget);
    expect(find.text('Farmer'), findsOneWidget);
    expect(find.text('Buyer'), findsOneWidget);
  });
}
