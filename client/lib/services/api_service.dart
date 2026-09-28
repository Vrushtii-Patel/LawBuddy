import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analytics_model.dart';
import '../models/stamp_duty_config_model.dart';
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

  static Future<String?> _getToken() async {
    return TokenStorage.getToken();
  }

  // =========================================================================
  // SHARED HTTP PIPELINE HELPERS
  // =========================================================================

  /// Core HTTP dispatcher handling token retrieval, header construction,
  /// request execution, and timeout management.
  static Future<http.Response> _sendRequest(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? explicitToken,
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    final token = explicitToken ?? (requiresAuth ? await _getToken() : null);
    final url = Uri.parse(endpoint.startsWith('http') ? endpoint : '$baseUrl$endpoint');

    final effectiveHeaders = <String, String>{
      if (body != null && body is! Uint8List) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (headers != null) ...headers,
    };

    final encodedBody = (body != null && body is! String && body is! Uint8List)
        ? jsonEncode(body)
        : body;

    Future<http.Response> sendFuture;
    switch (method.toUpperCase()) {
      case 'GET':
        sendFuture = http.get(url, headers: effectiveHeaders);
        break;
      case 'POST':
        sendFuture = http.post(url, headers: effectiveHeaders, body: encodedBody);
        break;
      case 'PUT':
        sendFuture = http.put(url, headers: effectiveHeaders, body: encodedBody);
        break;
      case 'PATCH':
        sendFuture = http.patch(url, headers: effectiveHeaders, body: encodedBody);
        break;
      case 'DELETE':
        sendFuture = http.delete(url, headers: effectiveHeaders, body: encodedBody);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    if (timeout != null) {
      sendFuture = sendFuture.timeout(timeout);
    }

    return await sendFuture;
  }

  /// Sends a multipart request (e.g. for document upload), handling token injection,
  /// fields, file bytes, content type, and streaming response conversion.
  static Future<http.Response> _sendMultipartRequest(
    String endpoint, {
    required String fileField,
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    Map<String, String>? fields,
    String? explicitToken,
    bool requiresAuth = true,
  }) async {
    final token = explicitToken ?? (requiresAuth ? await _getToken() : null);
    final url = Uri.parse(endpoint.startsWith('http') ? endpoint : '$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(http.MultipartFile.fromBytes(
      fileField,
      fileBytes,
      filename: filename,
      contentType: _getMediaType(mimeType),
    ));

    if (fields != null) {
      request.fields.addAll(fields);
    }

    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  /// Extracts error message from response body with fallbacks.
  static String _parseErrorMessage(http.Response response, {String fallback = 'An unexpected error occurred'}) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        if (body['error'] != null && body['error'].toString().isNotEmpty) {
          return body['error'].toString();
        }
        if (body['details'] != null && body['details'].toString().isNotEmpty) {
          return body['details'].toString();
        }
        if (body['message'] != null && body['message'].toString().isNotEmpty) {
          return body['message'].toString();
        }
      }
    } catch (_) {}
    return fallback;
  }

  /// Extracts error code from response body if present.
  static String? _parseErrorCode(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['code'] != null) {
        return body['code'].toString();
      }
    } catch (_) {}
    return null;
  }

  /// Evaluates the HTTP response for common error statuses (413, 429, 401, 403, 400+) and throws descriptive exceptions.
  static void _handleCommonErrors(
    http.Response response, {
    String? defaultErrorMessage,
    Map<int, String>? customStatusMessages,
  }) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;

    final code = _parseErrorCode(response);

    if (customStatusMessages != null && customStatusMessages.containsKey(status)) {
      throw ApiException(customStatusMessages[status]!, code: code, statusCode: status);
    }

    if (status == 429) {
      final parsedError = _parseErrorMessage(response, fallback: 'Rate limit reached. Please wait a moment before trying again.');
      throw RateLimitException(
        defaultErrorMessage != null && defaultErrorMessage.contains('Rate limit')
            ? defaultErrorMessage
            : parsedError,
        code: code,
        statusCode: status,
      );
    }
    if (status == 413) {
      throw ApiException('This document is too large. Please upload a smaller file.', code: code, statusCode: status);
    }
    if (status == 401) {
      final parsedError = _parseErrorMessage(response, fallback: 'Authentication expired. Please log in again.');
      throw ApiException(parsedError, code: code, statusCode: status);
    }
    if (status == 403) {
      final parsedError = _parseErrorMessage(response, fallback: 'Access Denied');
      throw ApiException(parsedError, code: code, statusCode: status);
    }

    final parsedError = _parseErrorMessage(response, fallback: defaultErrorMessage ?? 'Request failed ($status)');
    throw ApiException(parsedError, code: code, statusCode: status);
  }

  /// Convenience wrapper that sends a request, verifies 2xx status, and decodes JSON.
  static Future<dynamic> _requestJson(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? explicitToken,
    bool requiresAuth = true,
    String? defaultErrorMessage,
    Map<int, String>? customStatusMessages,
    Duration? timeout,
  }) async {
    final response = await _sendRequest(
      method,
      endpoint,
      body: body,
      headers: headers,
      explicitToken: explicitToken,
      requiresAuth: requiresAuth,
      timeout: timeout,
    );

    _handleCommonErrors(response, defaultErrorMessage: defaultErrorMessage, customStatusMessages: customStatusMessages);
    return jsonDecode(response.body);
  }

  /// Convenience wrapper for safe boolean endpoints (returns true on 200/201, false on error without throwing).
  static Future<bool> _requestBoolSafe(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? explicitToken,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _sendRequest(
        method,
        endpoint,
        body: body,
        headers: headers,
        explicitToken: explicitToken,
        requiresAuth: requiresAuth,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('API $method $endpoint error: $e');
      return false;
    }
  }

  /// Convenience wrapper for safe list endpoints (returns parsed List on 200/201, [] on error without throwing).
  static Future<List<dynamic>> _requestListSafe(
    String endpoint, {
    Map<String, String>? headers,
    String? explicitToken,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _sendRequest(
        'GET',
        endpoint,
        headers: headers,
        explicitToken: explicitToken,
        requiresAuth: requiresAuth,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
      }
      return [];
    } catch (e) {
      debugPrint('API GET $endpoint error: $e');
      return [];
    }
  }

  // =========================================================================
  // DOCUMENT SCANNING & SCAN JOBS
  // =========================================================================

  static Future<Map<String, dynamic>> scanDocument(
    String text, {
    String? title,
    String? sourceType,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    String? base64Data,
  }) async {
    http.Response response;
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final cleanMime = mimeType ?? 'application/pdf';
      final effectiveFileName = (fileName != null && fileName.isNotEmpty) ? fileName : (title ?? 'document.pdf');
      response = await _sendMultipartRequest(
        '/scan',
        fileField: 'document',
        fileBytes: fileBytes,
        filename: effectiveFileName,
        mimeType: cleanMime,
        fields: {
          if (title != null && title.isNotEmpty) 'title': title,
          if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
          if (text.isNotEmpty) 'text': text,
        },
      );
    } else {
      response = await _sendRequest(
        'POST',
        '/scan',
        body: {
          'text': text,
          if (title != null && title.isNotEmpty) 'title': title,
          if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
          if (base64Data != null && base64Data.isNotEmpty) 'base64Data': base64Data,
          if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
        },
      );
    }

    _handleCommonErrors(response, defaultErrorMessage: 'Failed to analyze document');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> scanDocumentFile(
    Uint8List bytes,
    String mimeType, {
    String? title,
    String? sourceType,
    String? fileName,
  }) async {
    final effectiveFileName = (fileName != null && fileName.isNotEmpty) ? fileName : (title ?? 'document.pdf');
    final response = await _sendMultipartRequest(
      '/scan-file',
      fileField: 'document',
      fileBytes: bytes,
      filename: effectiveFileName,
      mimeType: mimeType,
      fields: {
        if (title != null && title.isNotEmpty) 'title': title,
        if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
        'mimeType': mimeType,
      },
    );

    _handleCommonErrors(response, defaultErrorMessage: 'Failed to analyze document file');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> startScanJob({
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    String? title,
    String? sourceType,
    String? base64Data,
  }) async {
    http.Response response;
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final cleanMime = mimeType ?? 'application/pdf';
      final effectiveFileName = (fileName != null && fileName.isNotEmpty) ? fileName : (title ?? 'document.pdf');
      response = await _sendMultipartRequest(
        '/scans/start',
        fileField: 'document',
        fileBytes: fileBytes,
        filename: effectiveFileName,
        mimeType: cleanMime,
        fields: {
          if (title != null && title.isNotEmpty) 'title': title,
          if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
          if (text != null && text.isNotEmpty) 'text': text,
          if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
        },
      );
    } else {
      response = await _sendRequest(
        'POST',
        '/scans/start',
        body: {
          if (text != null && text.isNotEmpty) 'text': text,
          if (base64Data != null && base64Data.isNotEmpty) 'base64Data': base64Data,
          if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
          if (title != null && title.isNotEmpty) 'title': title,
          if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
        },
      );
    }

    _handleCommonErrors(
      response,
      defaultErrorMessage: 'Failed to start scan job',
      customStatusMessages: {
        400: _parseErrorMessage(
          response,
          fallback: 'This file type is not supported. Please upload a PDF or supported image.',
        ),
      },
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>?> getActiveScanJob() async {
    try {
      final response = await _sendRequest('GET', '/scans/active');
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
    final res = await _requestJson('GET', '/scans/$jobId', defaultErrorMessage: 'Failed to get scan job status');
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> retryScanJob(String jobId) async {
    final res = await _requestJson(
      'POST',
      '/scans/$jobId/retry',
      defaultErrorMessage: 'Failed to retry scan job',
      customStatusMessages: {
        429: 'Rate limit reached. Please wait before retrying.',
      },
    );
    return res as Map<String, dynamic>;
  }

  // =========================================================================
  // DOCUMENT MANAGEMENT & RECYCLE BIN
  // =========================================================================

  static Future<List<dynamic>> fetchRecentDocuments() async {
    return _requestListSafe('/documents');
  }

  static Future<Uint8List?> fetchDocumentFile(String documentId) async {
    try {
      final response = await _sendRequest('GET', '/documents/$documentId/file');
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
    return _requestBoolSafe('PATCH', '/documents/$documentId', body: {'title': newTitle.trim()});
  }

  static Future<bool> deleteDocument(String documentId) async {
    return _requestBoolSafe('DELETE', '/documents/$documentId');
  }

  static Future<List<dynamic>> fetchBinDocuments() async {
    return _requestListSafe('/documents/bin');
  }

  static Future<bool> restoreDocument(String documentId) async {
    return _requestBoolSafe('PATCH', '/documents/$documentId/restore');
  }

  static Future<bool> permanentlyDeleteDocument(String documentId) async {
    return _requestBoolSafe('DELETE', '/documents/$documentId/permanent');
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
      final response = await _sendRequest(
        'POST',
        '/shares',
        body: {
          if (documentId != null && documentId.isNotEmpty) 'documentId': documentId,
          'title': title,
          'riskLevel': riskLevel,
          'analysis': analysis,
          if (highRiskCount != null) 'highRiskCount': highRiskCount,
          if (cautionCount != null) 'cautionCount': cautionCount,
          if (compliantCount != null) 'compliantCount': compliantCount,
          if (totalClauseCount != null) 'totalClauseCount': totalClauseCount,
        },
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
      final response = await _sendRequest('GET', '/shares/$shareToken', requiresAuth: false);
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
    final data = await _requestJson(
      'POST',
      '/explain',
      body: {'context': context, 'snippet': snippet},
      defaultErrorMessage: 'Failed to explain snippet',
    );
    return data['explanation'];
  }

  static Future<List<dynamic>> getLegalNews() async {
    return _requestListSafe('/news/legal-updates', requiresAuth: false);
  }

  // =========================================================================
  // CHECKLISTS API METHODS
  // =========================================================================

  static Future<List<dynamic>> fetchAllChecklists() async {
    final res = await _requestJson('GET', '/checklists', defaultErrorMessage: 'Failed to load checklists');
    return res as List<dynamic>;
  }

  static Future<Map<String, dynamic>> fetchChecklist(String type) async {
    final res = await _requestJson('GET', '/checklists/$type', defaultErrorMessage: 'Failed to load checklist');
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateChecklistItem(String type, String itemId, bool isCompleted) async {
    final res = await _requestJson(
      'PUT',
      '/checklists/$type/items/$itemId',
      body: {'isCompleted': isCompleted},
      defaultErrorMessage: 'Failed to update checklist item',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> addChecklistItem(String type, String title) async {
    final res = await _requestJson(
      'POST',
      '/checklists/$type/items',
      body: {'title': title},
      defaultErrorMessage: 'Failed to add checklist item',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateChecklist(String prompt) async {
    final res = await _requestJson(
      'POST',
      '/checklists/generate',
      body: {'prompt': prompt},
      defaultErrorMessage: 'Failed to generate checklist',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteChecklistItem(String type, String itemId) async {
    final res = await _requestJson(
      'DELETE',
      '/checklists/$type/items/$itemId',
      defaultErrorMessage: 'Failed to delete checklist item',
    );
    return res as Map<String, dynamic>;
  }

  static Future<bool> deleteChecklist(String type) async {
    final response = await _sendRequest('DELETE', '/checklists/$type');
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> fetchBinChecklists() async {
    return _requestListSafe('/checklists/bin');
  }

  static Future<bool> restoreChecklist(String idOrType) async {
    return _requestBoolSafe('PATCH', '/checklists/$idOrType/restore');
  }

  static Future<bool> permanentlyDeleteChecklist(String idOrType) async {
    return _requestBoolSafe('DELETE', '/checklists/$idOrType/permanent');
  }

  static Future<Map<String, dynamic>> renameChecklist(String type, String title) async {
    final res = await _requestJson(
      'PUT',
      '/checklists/$type/rename',
      body: {'title': title},
      defaultErrorMessage: 'Failed to rename checklist',
    );
    return res as Map<String, dynamic>;
  }

  static Future<void> syncChecklistsWithDocument(String documentId) async {
    try {
      await _sendRequest('POST', '/checklists/sync/$documentId');
    } catch (e) {
      debugPrint('Checklist sync error: $e');
    }
  }

  static Future<void> syncAllChecklists() async {
    try {
      await _sendRequest('POST', '/checklists/sync');
    } catch (e) {
      debugPrint('Checklist sync all error: $e');
    }
  }

  // =========================================================================
  // CHAT API METHODS
  // =========================================================================

  static Future<Map<String, dynamic>> chat(List<Map<String, dynamic>> history, {String? sessionId}) async {
    final sanitizedHistory = history.map((m) => {
      'role': m['role'],
      'text': m['text'],
      if (m['time'] != null) 'time': m['time'],
    }).toList();

    final res = await _requestJson(
      'POST',
      '/chat',
      body: {
        'history': sanitizedHistory,
        if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
      },
      defaultErrorMessage: 'Failed to send chat message',
      customStatusMessages: {
        429: 'Rate limit reached. Please wait a moment before sending another message.',
      },
    );
    return res as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchChatSessions() async {
    return _requestListSafe('/chat/sessions');
  }

  static Future<Map<String, dynamic>> fetchChatSession(String sessionId) async {
    final res = await _requestJson('GET', '/chat/sessions/$sessionId', defaultErrorMessage: 'Failed to load chat session');
    return res as Map<String, dynamic>;
  }

  static Future<bool> deleteChatSession(String sessionId) async {
    return _requestBoolSafe('DELETE', '/chat/sessions/$sessionId');
  }

  // =========================================================================
  // AUTHENTICATION API METHODS
  // =========================================================================

  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) async {
    final res = await _requestJson(
      'POST',
      '/auth/signup',
      body: {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'accepted_terms': acceptedTerms,
      },
      requiresAuth: false,
      defaultErrorMessage: 'Failed to sign up',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final res = await _requestJson(
      'POST',
      '/auth/verify-email',
      body: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      },
      requiresAuth: false,
      defaultErrorMessage: 'Failed to verify email',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _requestJson(
      'POST',
      '/auth/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      requiresAuth: false,
      defaultErrorMessage: 'Failed to log in',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final res = await _requestJson(
      'POST',
      '/auth/forgot-password',
      body: {
        'email': email.trim().toLowerCase(),
      },
      requiresAuth: false,
      defaultErrorMessage: 'Failed to request password reset',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final res = await _requestJson(
      'POST',
      '/auth/reset-password',
      body: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
        'new_password': newPassword,
      },
      requiresAuth: false,
      defaultErrorMessage: 'Failed to reset password',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> resendOtp({
    required String email,
    required String purpose, // 'signup' | 'reset'
  }) async {
    final res = await _requestJson(
      'POST',
      '/auth/resend-otp',
      body: {
        'email': email.trim().toLowerCase(),
        'purpose': purpose,
      },
      requiresAuth: false,
      defaultErrorMessage: 'Failed to resend OTP',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> logout({String? explicitToken}) async {
    final res = await _requestJson(
      'POST',
      '/auth/logout',
      explicitToken: explicitToken,
      requiresAuth: true,
      defaultErrorMessage: 'Failed to log out',
    );
    return (res is Map<String, dynamic>) ? res : {'success': true};
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    final res = await _requestJson(
      'GET',
      '/auth/me',
      explicitToken: token,
      defaultErrorMessage: 'Failed to fetch profile',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? profilePhoto,
    String? preferredLanguage,
    String? dateOfBirth,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (profilePhoto != null) 'profile_photo': profilePhoto,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
    };
    final res = await _requestJson(
      'PUT',
      '/auth/profile',
      body: body,
      requiresAuth: true,
      defaultErrorMessage: 'Failed to update profile',
    );
    return res as Map<String, dynamic>;
  }

  // =========================================================================
  // STAMP DUTY CALCULATOR & CONFIG METHODS
  // =========================================================================

  static Future<Map<String, dynamic>> saveStampDutyCalculation(Map<String, dynamic> data) async {
    try {
      final response = await _sendRequest('POST', '/stamp-duty', body: data);
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
    return _requestListSafe('/stamp-duty');
  }

  static const String _stampDutyConfigCacheKey = 'stamp_duty_config_cache';

  /// Fetches authoritative stamp duty rules & state configs from backend,
  /// with local SharedPreferences offline caching and resilient defaults.
  static Future<StampDutyConfigResponse> getStampDutyConfig() async {
    try {
      final response = await _sendRequest(
        'GET',
        '/stamp-duty-config',
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          // Cache successful response locally for offline resilience
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_stampDutyConfigCacheKey, response.body);
          } catch (cacheErr) {
            debugPrint('Failed to write stamp duty config to cache: $cacheErr');
          }
          return StampDutyConfigResponse.fromJson(body);
        }
      }
    } catch (e) {
      debugPrint('Error fetching stamp duty config from backend (falling back to cache): $e');
    }

    // Try reading from SharedPreferences offline cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_stampDutyConfigCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map<String, dynamic>) {
          return StampDutyConfigResponse.fromJson(decoded);
        }
      }
    } catch (cacheReadErr) {
      debugPrint('Error reading stamp duty config from local cache: $cacheReadErr');
    }

    // Fallback to built-in default statutory bundle
    return StampDutyConfigResponse.defaultBundle();
  }

  // =========================================================================
  // ADMIN ANALYTICS METHODS
  // =========================================================================

  static Future<AdminAnalyticsData> fetchAdminAnalytics() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in.');
    }

    final response = await _sendRequest('GET', '/admin/analytics', explicitToken: token);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return AdminAnalyticsData.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please log in again.');
    } else if (response.statusCode == 403) {
      throw Exception('Access Denied: Admin authorization is required to view system analytics.');
    } else {
      final parsedError = _parseErrorMessage(response, fallback: 'Failed to load system analytics (${response.statusCode})');
      throw Exception(parsedError);
    }
  }

  // =========================================================================
  // DOCUMENT COMPARISON METHODS
  // =========================================================================

  static Future<Map<String, dynamic>> startComparison({
    String? docAId,
    String? docBId,
    Map<String, dynamic>? fileA,
    Map<String, dynamic>? fileB,
    String? titleA,
    String? titleB,
  }) async {
    final res = await _requestJson(
      'POST',
      '/comparisons/start',
      body: {
        if (docAId != null) 'docAId': docAId,
        if (docBId != null) 'docBId': docBId,
        if (fileA != null) 'fileA': fileA,
        if (fileB != null) 'fileB': fileB,
        if (titleA != null) 'titleA': titleA,
        if (titleB != null) 'titleB': titleB,
      },
      defaultErrorMessage: 'Failed to start comparison',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> getActiveComparison() async {
    try {
      final response = await _sendRequest('GET', '/comparisons/active');
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
    final res = await _requestJson(
      'GET',
      '/comparisons/$comparisonId',
      defaultErrorMessage: 'Failed to load comparison details',
    );
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> retryComparison(String comparisonId) async {
    final res = await _requestJson(
      'POST',
      '/comparisons/$comparisonId/retry',
      defaultErrorMessage: 'Failed to retry comparison',
    );
    return res as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchComparisons() async {
    return _requestListSafe('/comparisons');
  }

  static Future<bool> deleteComparison(String comparisonId) async {
    return _requestBoolSafe('DELETE', '/comparisons/$comparisonId');
  }
}

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  ApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() => message;
}

class RateLimitException extends ApiException {
  RateLimitException(super.message, {super.code, super.statusCode = 429});

  @override
  String toString() => message;
}