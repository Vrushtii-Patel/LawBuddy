import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/analytics_model.dart';
import 'token_storage.dart';


class ApiService {
  static String get baseUrl {
    const String envApiUrl = String.fromEnvironment('API_URL');
    if (envApiUrl.isNotEmpty) {
      return envApiUrl;
    }
    
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  static MediaType _getMediaType(String mimeType) {
    try {
      final parts = mimeType.split('/');
      if (parts.length == 2) {
        return MediaType(parts[0], parts[1]);
      }
    } catch (_) {}
    return MediaType('application', 'pdf');
  }

  static Future<Map<String, dynamic>> scanDocument(
    String text, {
    String? title,
    String? sourceType,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    String? base64Data,
  }) async {
    final token = await _getToken();

    if (fileBytes != null && fileBytes.isNotEmpty) {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final cleanMime = mimeType ?? 'application/pdf';
      final effectiveFileName = (fileName != null && fileName.isNotEmpty) ? fileName : (title ?? 'document.pdf');
      request.files.add(http.MultipartFile.fromBytes(
        'document',
        fileBytes,
        filename: effectiveFileName,
        contentType: _getMediaType(cleanMime),
      ));
      if (title != null && title.isNotEmpty) request.fields['title'] = title;
      if (sourceType != null && sourceType.isNotEmpty) request.fields['sourceType'] = sourceType;
      if (text.isNotEmpty) request.fields['text'] = text;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 413) {
        throw Exception('This document is too large. Please upload a smaller file.');
      } else if (response.statusCode == 429) {
        throw RateLimitException('Rate limit reached. Please try again later.');
      } else {
        String errorMessage = 'Failed to analyze document';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && (body['error'] != null || body['details'] != null)) {
            errorMessage = body['error'] ?? body['details'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } else {
      final response = await http.post(
        Uri.parse('$baseUrl/scan'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': text,
          if (title != null && title.isNotEmpty) 'title': title,
          if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
          if (base64Data != null && base64Data.isNotEmpty) 'base64Data': base64Data,
          if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 429) {
        throw RateLimitException('Rate limit reached. Please try again later.');
      } else {
        String errorMessage = 'Failed to analyze document';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && (body['error'] != null || body['details'] != null)) {
            errorMessage = body['error'] ?? body['details'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    }
  }

  static Future<Map<String, dynamic>> scanDocumentFile(
    Uint8List bytes,
    String mimeType, {
    String? title,
    String? sourceType,
    String? fileName,
  }) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan-file'));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final effectiveFileName = (fileName != null && fileName.isNotEmpty) ? fileName : (title ?? 'document.pdf');
    request.files.add(http.MultipartFile.fromBytes(
      'document',
      bytes,
      filename: effectiveFileName,
      contentType: _getMediaType(mimeType),
    ));
    if (title != null && title.isNotEmpty) request.fields['title'] = title;
    if (sourceType != null && sourceType.isNotEmpty) request.fields['sourceType'] = sourceType;
    request.fields['mimeType'] = mimeType;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 413) {
      throw Exception('This document is too large. Please upload a smaller file.');
    } else if (response.statusCode == 429) {
      throw RateLimitException('Rate limit reached. Please try again later.');
    } else {
      String errorMessage = 'Failed to analyze document file';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && (body['error'] != null || body['details'] != null)) {
          errorMessage = body['error'] ?? body['details'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  // =========================================================================
  // RESUMABLE SCAN JOB API METHODS
  // =========================================================================

  static Future<Map<String, dynamic>> startScanJob({
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    String? title,
    String? sourceType,
    String? base64Data,
  }) async {
    final token = await _getToken();

    if (fileBytes != null && fileBytes.isNotEmpty) {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scans/start'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final cleanMime = mimeType ?? 'application/pdf';
      final effectiveFileName = (fileName != null && fileName.isNotEmpty) ? fileName : (title ?? 'document.pdf');
      request.files.add(http.MultipartFile.fromBytes(
        'document',
        fileBytes,
        filename: effectiveFileName,
        contentType: _getMediaType(cleanMime),
      ));
      if (title != null && title.isNotEmpty) request.fields['title'] = title;
      if (sourceType != null && sourceType.isNotEmpty) request.fields['sourceType'] = sourceType;
      if (text != null && text.isNotEmpty) request.fields['text'] = text;
      if (mimeType != null && mimeType.isNotEmpty) request.fields['mimeType'] = mimeType;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 413) {
        throw Exception('This document is too large. Please upload a smaller file.');
      } else if (response.statusCode == 400) {
        String errorMessage = 'This file type is not supported. Please upload a PDF or supported image.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['error'] != null) errorMessage = body['error'];
        } catch (_) {}
        throw Exception(errorMessage);
      } else {
        String errorMessage = 'Failed to start scan job';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && (body['error'] != null || body['details'] != null)) {
            errorMessage = body['error'] ?? body['details'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } else {
      final response = await http.post(
        Uri.parse('$baseUrl/scans/start'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (text != null && text.isNotEmpty) 'text': text,
          if (base64Data != null && base64Data.isNotEmpty) 'base64Data': base64Data,
          if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
          if (title != null && title.isNotEmpty) 'title': title,
          if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        String errorMessage = 'Failed to start scan job';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && (body['error'] != null || body['details'] != null)) {
            errorMessage = body['error'] ?? body['details'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    }
  }

  static Future<Map<String, dynamic>?> getActiveScanJob() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/scans/active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['activeJob'] != null) {
          return Map<String, dynamic>.from(data['activeJob']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active scan job: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getScanJob(String jobId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/scans/$jobId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to get scan job status';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && (body['error'] != null || body['details'] != null)) {
          errorMessage = body['error'] ?? body['details'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<Map<String, dynamic>> retryScanJob(String jobId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/scans/$jobId/retry'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 429) {
      throw RateLimitException('Rate limit reached. Please wait before retrying.');
    } else {
      String errorMessage = 'Failed to retry scan job';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && (body['error'] != null || body['details'] != null)) {
          errorMessage = body['error'] ?? body['details'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<List<dynamic>> fetchRecentDocuments() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/documents'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    }
  }

  static Future<Uint8List?> fetchDocumentFile(String documentId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/documents/$documentId/file'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching document file: $e');
      return null;
    }
  }

  static Future<bool> renameDocument(String documentId, String newTitle) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'title': newTitle.trim()}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error renaming document: $e');
      return false;
    }
  }

  static Future<bool> deleteDocument(String documentId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }

  // =========================================================================
  // SHARE RISK SUMMARY API METHODS
  // =========================================================================

  static Future<String?> createShareLink({
    String? documentId,
    required String title,
    required String riskLevel,
    required List<dynamic> analysis,
    int? highRiskCount,
    int? cautionCount,
    int? compliantCount,
    int? totalClauseCount,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/shares'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (documentId != null && documentId.isNotEmpty) 'documentId': documentId,
          'title': title,
          'riskLevel': riskLevel,
          'analysis': analysis,
          if (highRiskCount != null) 'highRiskCount': highRiskCount,
          if (cautionCount != null) 'cautionCount': cautionCount,
          if (compliantCount != null) 'compliantCount': compliantCount,
          if (totalClauseCount != null) 'totalClauseCount': totalClauseCount,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['shareToken'] as String?;
      } else {
        debugPrint('Failed to create share link: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating share link: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSharedSummary(String shareToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shares/$shareToken'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Shared summary not found or error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching shared summary: $e');
      return null;
    }
  }

  /// Base URL for share links.
  /// Configurable via `--dart-define=SHARE_BASE_URL=https://your-domain.com/`.
  /// Defaults to browser origin on web, or development/testing repository URL as fallback.
  static String get shareBaseUrl {
    const String envShareUrl = String.fromEnvironment('SHARE_BASE_URL');
    if (envShareUrl.isNotEmpty) {
      return envShareUrl;
    }
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
    }
    // Development/testing fallback URL until production deployment domain is configured
    return 'https://vrushti1303.github.io/Final-year-project/';
  }

  static String buildShareUrl(String shareToken) {
    final base = shareBaseUrl;
    final separator = base.contains('?') ? '&' : (base.endsWith('/') ? '?' : '/?');
    return '$base${separator}share=$shareToken';
  }

  static Future<String> explainSnippet(String context, String snippet) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/explain'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'context': context, 'snippet': snippet}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['explanation'];
    } else if (response.statusCode == 429) {
      throw RateLimitException('Rate limit reached. Please try again later.');
    } else {
      throw Exception('Failed to explain snippet');
    }
  }

  static Future<List<dynamic>> getLegalNews() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/news/legal-updates'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching legal news: $e');
      return [];
    }
  }

  static Future<String?> _getToken() async {
    return TokenStorage.getToken();
  }

  static Future<List<dynamic>> fetchAllChecklists() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/checklists'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      }
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load checklists');
    }
  }

  static Future<Map<String, dynamic>> fetchChecklist(String type) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/checklists/$type'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      }
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load checklist');
    }
  }

  static Future<Map<String, dynamic>> updateChecklistItem(String type, String itemId, bool isCompleted) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/checklists/$type/items/$itemId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'isCompleted': isCompleted}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update checklist item');
    }
  }

  static Future<Map<String, dynamic>> addChecklistItem(String type, String title) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/checklists/$type/items'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'title': title}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add checklist item');
    }
  }

  static Future<Map<String, dynamic>> generateChecklist(String prompt) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/checklists/generate'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'prompt': prompt}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate checklist');
    }
  }

  static Future<Map<String, dynamic>> deleteChecklistItem(String type, String itemId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/checklists/$type/items/$itemId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete checklist item');
    }
  }

  static Future<bool> deleteChecklist(String type) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/checklists/$type'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> renameChecklist(String type, String title) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/checklists/$type/rename'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'title': title}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to rename checklist');
    }
  }

  static Future<void> syncChecklistsWithDocument(String documentId) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('$baseUrl/checklists/sync/$documentId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint('Checklist sync error: $e');
    }
  }

  static Future<void> syncAllChecklists() async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('$baseUrl/checklists/sync'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint('Checklist sync all error: $e');
    }
  }

  static Future<Map<String, dynamic>> chat(List<Map<String, dynamic>> history, {String? sessionId}) async {
    final token = await _getToken();
    final sanitizedHistory = history.map((m) => {
      'role': m['role'],
      'text': m['text'],
      if (m['time'] != null) 'time': m['time'],
    }).toList();
    
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'history': sanitizedHistory,
        if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 429) {
      throw RateLimitException('Rate limit reached. Please wait a moment before sending another message.');
    } else {
      throw Exception('Failed to send chat message');
    }
  }

  static Future<List<dynamic>> fetchChatSessions() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/chat/sessions'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching chat sessions: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchChatSession(String sessionId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/sessions/$sessionId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chat session');
    }
  }

  static Future<bool> deleteChatSession(String sessionId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/chat/sessions/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting chat session: $e');
      return false;
    }
  }

  // Auth Methods
  static Future<Map<String, dynamic>> sendOtp({
    required String email,
    required String type, // 'login' or 'signup'
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'type': type,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to send OTP';
      throw Exception(error);
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    required String type,
    String? fullName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'type': type,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to verify OTP';
      throw Exception(error);
    }
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to resend OTP';
      throw Exception(error);
    }
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch profile');
    }
  }

  // Stamp Duty DB methods
  static Future<Map<String, dynamic>> saveStampDutyCalculation(Map<String, dynamic> data) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/stamp-duty'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint('Error saving stamp duty calculation to DB: $e');
      return {};
    }
  }

  static Future<List<dynamic>> fetchStampDutyHistory() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/stamp-duty'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching stamp duty history: $e');
      return [];
    }
  }

  // Admin Analytics Method
  static Future<AdminAnalyticsData> fetchAdminAnalytics() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/admin/analytics'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return AdminAnalyticsData.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please log in again.');
    } else if (response.statusCode == 403) {
      throw Exception('Access Denied: Admin authorization is required to view system analytics.');
    } else {
      String errorMessage = 'Failed to load system analytics (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          errorMessage = body['error'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  // Document Comparison methods
  static Future<Map<String, dynamic>> startComparison({
    String? docAId,
    String? docBId,
    Map<String, dynamic>? fileA,
    Map<String, dynamic>? fileB,
    String? titleA,
    String? titleB,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/comparisons/start'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (docAId != null) 'docAId': docAId,
        if (docBId != null) 'docBId': docBId,
        if (fileA != null) 'fileA': fileA,
        if (fileB != null) 'fileB': fileB,
        if (titleA != null) 'titleA': titleA,
        if (titleB != null) 'titleB': titleB,
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to start comparison';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && (body['error'] != null || body['details'] != null)) {
          errorMessage = body['error'] ?? body['details'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<Map<String, dynamic>?> getActiveComparison() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/comparisons/active'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['activeComparison'];
      }
      return null;
    } catch (e) {
      debugPrint('Error checking active comparison: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getComparison(String comparisonId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/comparisons/$comparisonId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load comparison details');
    }
  }

  static Future<Map<String, dynamic>> retryComparison(String comparisonId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/comparisons/$comparisonId/retry'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to retry comparison');
    }
  }

  static Future<List<dynamic>> fetchComparisons() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/comparisons'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching comparisons: $e');
      return [];
    }
  }

  static Future<bool> deleteComparison(String comparisonId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/comparisons/$comparisonId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting comparison: $e');
      return false;
    }
  }
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  
  @override
  String toString() => message;
}