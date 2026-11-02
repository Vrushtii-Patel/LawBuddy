import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_scanner/screens/chat/chat_citation_card.dart';

void main() {
  testWidgets(
      'LegalSourcesCitationCard renders cleanly on mobile viewport without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final sources = [
      {
        'document':
            'Maharashtra Real Estate (Regulation and Development) (Registration of real estate projects, Registration of real estate agents, rates of interest and disclosures on website) Rules, 2017',
        'rule': 10,
        'authority': 'MahaRERA / Government of Maharashtra',
        'jurisdiction': 'Maharashtra',
        'sourceUrl': 'https://maharera.mahaonline.gov.in',
      },
      {
        'document': 'Transfer of Property Act, 1882',
        'section': '105, 107',
        'authority': 'India Code',
        'jurisdiction': 'India',
        'sourceUrl': 'https://indiacode.nic.in',
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LegalSourcesCitationCard(
                sources: sources,
                isDark: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title accordion is visible
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);

    // Tap to expand
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Verify Rule 10 is formatted as 'Rule 10' (not just raw '10')
    expect(find.text('Rule 10'), findsOneWidget);

    // Verify Sec 105, 107 is formatted properly
    expect(find.text('Sec 105, 107'), findsOneWidget);

    // Verify Official Source is rendered
    expect(find.text('Official Source'), findsNWidgets(2));

    // Verify no exceptions or overflows were thrown
    expect(tester.takeException(), isNull);
  });
}
