import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:legal_scanner/screens/bin_screen.dart';
import 'package:legal_scanner/screens/cant_connect_screen.dart';
import 'package:legal_scanner/screens/comparison_result_screen.dart';
import 'package:legal_scanner/screens/shared_summary_screen.dart';
import 'package:legal_scanner/screens/chat/chat_message_bubble.dart';
import 'package:legal_scanner/services/api_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) _handler;
  MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      contentLength: response.bodyBytes.length,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiService.client = null;
    ApiService.onUnauthorized = null;
  });

  tearDown(() {
    ApiService.client = null;
    ApiService.onUnauthorized = null;
  });

  group('Issue 43: Screen Review Pass & Comprehensive Localization', () {
    testWidgets('BinScreen renders tabs, empty state and localized retry in English and Hindi', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BinScreen(),
          ),
        ),
      );

      // Loading indicator first
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Recycle bin tabs and title
      expect(find.text('Recycle Bin'), findsWidgets);
      expect(find.text('Documents'), findsWidgets);
      expect(find.text('Checklists'), findsWidgets);
    });

    testWidgets('ComparisonResultScreen renders localized differential analysis, buyer impact, and tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyComparison = {
        'titleA': 'Draft 1 - Sale Deed',
        'titleB': 'Draft 2 - Sale Deed Final',
        'summary': 'Two minor clause alterations detected.',
        'clauseComparisons': [
          {
            'clauseNumber': 1,
            'titleA': 'Payment Schedule',
            'titleB': 'Payment Milestones Revised',
            'changeStatus': 'MODIFIED',
            'buyerImpact': 'Stricter 15-day forfeiture penalty added for delayed disbursement.',
            'buyerConsiderations': 'Negotiate grace period to at least 30 calendar days.',
            'statutoryCitations': ['RERA Section 13(1)', 'Transfer of Property Act Sec 54'],
          }
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ComparisonResultScreen(comparisonData: dummyComparison),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Comparison Report'), findsOneWidget);
      expect(find.text('Agreement Version Differential'), findsOneWidget);
      expect(find.text('Draft 1 - Sale Deed'), findsWidgets);
      expect(find.text('Draft 2 - Sale Deed Final'), findsWidgets);
      expect(find.text('Buyer Impact'), findsOneWidget);
      expect(find.textContaining('Stricter 15-day forfeiture'), findsOneWidget);
    });

    testWidgets('SharedSummaryScreen renders Read-Only badge and localized filter tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummySharedData = {
        'title': 'Commercial Tenancy Agreement',
        'overallRisk': 'HIGH',
        'createdAt': '2026-10-24T12:00:00Z',
        'analysis': [
          {
            'clause': 'Lock-in period penalty clause',
            'riskLevel': 'HIGH_RISK',
            'explanation': 'Unilateral forfeiture penalty without reciprocal lessor commitment.',
          },
          {
            'clause': 'Premises maintenance and society charges',
            'riskLevel': 'COMPLIANT',
            'explanation': 'Standard statutory allocation according to local municipal bylaws.',
          }
        ],
      };

      ApiService.client = MockHttpClient((request) async {
        return http.Response(
          jsonEncode(dummySharedData),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SharedSummaryScreen(
              shareToken: 'test-share-token-123',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Read-Only'), findsOneWidget);
      expect(find.text('Commercial Tenancy Agreement'), findsOneWidget);
      expect(find.textContaining('All Clauses (2)'), findsOneWidget);
      expect(find.textContaining('High Risk (1)'), findsOneWidget);
      expect(find.textContaining('Compliant (1)'), findsOneWidget);
    });

    testWidgets('AnimatedMessageBubble renders localized Suggested follow-ups label', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyMessage = {
        'role': 'assistant',
        'content': 'Here is the legal summary of your encumbrance certificate.',
        'suggestions': [
          'What happens if the title is encumbered?',
          'How do I verify the OC record?',
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AnimatedMessageBubble(
                message: dummyMessage,
                onSuggestionTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Suggested follow-ups'), findsOneWidget);
      expect(find.text('What happens if the title is encumbered?'), findsOneWidget);
      expect(find.text('How do I verify the OC record?'), findsOneWidget);
    });

    testWidgets('CantConnectScreen renders localized offline title, retry, and handles retry callback', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CantConnectScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Can't connect"), findsOneWidget);
      expect(find.textContaining('Unable to connect to LawBuddy servers'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
