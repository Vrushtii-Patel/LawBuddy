import 'package:flutter_test/flutter_test.dart';
import 'package:legal_scanner/services/api_service.dart';

void main() {
  group('ApiService URL and helper tests', () {
    test('baseUrl returns non-empty url', () {
      expect(ApiService.baseUrl, isNotEmpty);
      expect(ApiService.baseUrl.contains('/api'), isTrue);
    });

    test('buildShareUrl formats link with token correctly', () {
      final url = ApiService.buildShareUrl('token123');
      expect(url.contains('share=token123'), isTrue);
    });

    test('RateLimitException prints message correctly', () {
      final ex = RateLimitException('Too many requests');
      expect(ex.toString(), equals('Too many requests'));
    });
  });
}
