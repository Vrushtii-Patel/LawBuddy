import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analytics_model.dart';


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


  static Future<Map<String, dynamic>> scanDocument(String text, {String? title, String? sourceType, String? base64Data, String? mimeType}) async {
    final token = await _getToken();
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

  static Future<Map<String, dynamic>> scanDocumentFile(Uint8List bytes, String mimeType, {String? title, String? sourceType}) async {
    final token = await _getToken();
    final String base64Data = base64Encode(bytes);
    final response = await http.post(
      Uri.parse('$baseUrl/scan-file'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'base64Data': base64Data,
        'mimeType': mimeType,
        if (title != null && title.isNotEmpty) 'title': title,
        if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
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
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  
  @override
  String toString() => message;
}