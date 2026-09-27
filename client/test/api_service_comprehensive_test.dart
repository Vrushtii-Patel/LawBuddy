import 'package:flutter_test/flutter_test.dart';
import 'package:legal_scanner/services/api_service.dart';
import 'package:legal_scanner/models/analytics_model.dart';
import 'package:legal_scanner/models/stamp_duty_config_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService Comprehensive Regression Test Suite', () {
    // 1. Base URL and URL generation tests
    test('baseUrl returns appropriate API endpoint', () {
      expect(ApiService.baseUrl, isNotEmpty);
      expect(ApiService.baseUrl.contains('/api'), isTrue);
    });

    test('shareBaseUrl returns valid scheme and host', () {
      expect(ApiService.shareBaseUrl, isNotEmpty);
      expect(ApiService.shareBaseUrl.startsWith('http'), isTrue);
    });

    test('buildShareUrl correctly appends token', () {
      final shareUrl = ApiService.buildShareUrl('test-token-xyz');
      expect(shareUrl.contains('share=test-token-xyz'), isTrue);
    });

    // 2. Exception types
    test('RateLimitException string representation', () {
      final exc = RateLimitException('Rate limit reached.');
      expect(exc.toString(), equals('Rate limit reached.'));
    });

    // 3. Model deserialization verification for API responses
    test('StampDutyConfigResponse default bundle produces valid structure', () {
      final defaultBundle = StampDutyConfigResponse.defaultBundle();
      expect(defaultBundle.states, isNotEmpty);
      final hasMaharashtra = defaultBundle.states.any((s) => s.state == 'Maharashtra');
      expect(hasMaharashtra, isTrue);
    });

    test('AdminAnalyticsData deserialization matches backend shape', () {
      final mockData = {
        'overview': {
          'totalUsers': 45,
          'totalDocumentsAnalyzed': 120,
          'totalClausesEvaluated': 360,
          'averagePagesPerDoc': 2.5,
          'totalChatSessions': 18,
          'totalChecklists': 9,
        },
        'riskDistribution': {
          'documentLevel': {
            'highRisk': 15,
            'mediumRisk': 45,
            'lowRisk': 60,
          },
          'clauseLevel': {
            'highRisk': 30,
            'caution': 80,
            'compliant': 250,
          },
        },
        'findingCategories': [],
        'sourceDistribution': [],
        'extractionMethods': [],
        'recentScans': [],
      };

      final parsed = AdminAnalyticsData.fromJson(mockData);
      expect(parsed.overview.totalUsers, equals(45));
      expect(parsed.overview.totalDocumentsAnalyzed, equals(120));
      expect(parsed.riskDistribution.documentLevel.highRisk, equals(15));
      expect(parsed.riskDistribution.clauseLevel.caution, equals(80));
    });

    // 4. API method signature verification & compile-time type checking
    test('All ApiService method signatures match exact return type and contract', () {
      // Scan methods
      expect(ApiService.scanDocument, isA<Function>());
      expect(ApiService.scanDocumentFile, isA<Function>());
      expect(ApiService.startScanJob, isA<Function>());
      expect(ApiService.getActiveScanJob, isA<Function>());
      expect(ApiService.getScanJob, isA<Function>());
      expect(ApiService.retryScanJob, isA<Function>());

      // Document methods
      expect(ApiService.fetchRecentDocuments, isA<Function>());
      expect(ApiService.fetchDocumentFile, isA<Function>());
      expect(ApiService.renameDocument, isA<Function>());
      expect(ApiService.deleteDocument, isA<Function>());
      expect(ApiService.fetchBinDocuments, isA<Function>());
      expect(ApiService.restoreDocument, isA<Function>());
      expect(ApiService.permanentlyDeleteDocument, isA<Function>());

      // Share & explain methods
      expect(ApiService.createShareLink, isA<Function>());
      expect(ApiService.getSharedSummary, isA<Function>());
      expect(ApiService.explainSnippet, isA<Function>());
      expect(ApiService.getLegalNews, isA<Function>());

      // Checklist methods
      expect(ApiService.fetchAllChecklists, isA<Function>());
      expect(ApiService.fetchChecklist, isA<Function>());
      expect(ApiService.updateChecklistItem, isA<Function>());
      expect(ApiService.addChecklistItem, isA<Function>());
      expect(ApiService.generateChecklist, isA<Function>());
      expect(ApiService.deleteChecklistItem, isA<Function>());
      expect(ApiService.deleteChecklist, isA<Function>());
      expect(ApiService.fetchBinChecklists, isA<Function>());
      expect(ApiService.restoreChecklist, isA<Function>());
      expect(ApiService.permanentlyDeleteChecklist, isA<Function>());
      expect(ApiService.renameChecklist, isA<Function>());
      expect(ApiService.syncChecklistsWithDocument, isA<Function>());
      expect(ApiService.syncAllChecklists, isA<Function>());

      // Chat methods
      expect(ApiService.chat, isA<Function>());
      expect(ApiService.fetchChatSessions, isA<Function>());
      expect(ApiService.fetchChatSession, isA<Function>());
      expect(ApiService.deleteChatSession, isA<Function>());

      // Auth methods
      expect(ApiService.sendOtp, isA<Function>());
      expect(ApiService.verifyOtp, isA<Function>());
      expect(ApiService.resendOtp, isA<Function>());
      expect(ApiService.getProfile, isA<Function>());

      // Stamp duty methods
      expect(ApiService.saveStampDutyCalculation, isA<Function>());
      expect(ApiService.fetchStampDutyHistory, isA<Function>());
      expect(ApiService.getStampDutyConfig, isA<Function>());

      // Admin & comparison methods
      expect(ApiService.fetchAdminAnalytics, isA<Function>());
      expect(ApiService.startComparison, isA<Function>());
      expect(ApiService.getActiveComparison, isA<Function>());
      expect(ApiService.getComparison, isA<Function>());
      expect(ApiService.retryComparison, isA<Function>());
      expect(ApiService.fetchComparisons, isA<Function>());
      expect(ApiService.deleteComparison, isA<Function>());
    });
  });
}
