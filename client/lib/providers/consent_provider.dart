import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsentState {
  final bool hasDecided;
  final bool functionalEnabled;
  final String? status; // 'accepted_all', 'necessary_only', 'custom'
  final DateTime? timestamp;

  const ConsentState({
    this.hasDecided = false,
    this.functionalEnabled = true,
    this.status,
    this.timestamp,
  });

  ConsentState copyWith({
    bool? hasDecided,
    bool? functionalEnabled,
    String? status,
    DateTime? timestamp,
  }) {
    return ConsentState(
      hasDecided: hasDecided ?? this.hasDecided,
      functionalEnabled: functionalEnabled ?? this.functionalEnabled,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  static const String _statusKey = 'storage_consent_status';
  static const String _functionalKey = 'storage_consent_functional';
  static const String _timestampKey = 'storage_consent_timestamp';

  ConsentNotifier() : super(const ConsentState()) {
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = prefs.getString(_statusKey);
      final functional = prefs.getBool(_functionalKey);
      final timeStr = prefs.getString(_timestampKey);

      if (status != null) {
        state = ConsentState(
          hasDecided: true,
          functionalEnabled: functional ?? (status == 'accepted_all'),
          status: status,
          timestamp: timeStr != null ? DateTime.tryParse(timeStr) : null,
        );
      }
    } catch (_) {
      // Graceful fallback to default state
    }
  }

  Future<void> acceptAll() async {
    final now = DateTime.now();
    state = ConsentState(
      hasDecided: true,
      functionalEnabled: true,
      status: 'accepted_all',
      timestamp: now,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, 'accepted_all');
      await prefs.setBool(_functionalKey, true);
      await prefs.setString(_timestampKey, now.toIso8601String());
    } catch (_) {}
  }

  Future<void> necessaryOnly() async {
    final now = DateTime.now();
    state = ConsentState(
      hasDecided: true,
      functionalEnabled: false,
      status: 'necessary_only',
      timestamp: now,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, 'necessary_only');
      await prefs.setBool(_functionalKey, false);
      await prefs.setString(_timestampKey, now.toIso8601String());
      await prefs.remove('theme_preference');
      await prefs.remove('app_language_preference');
    } catch (_) {}
  }

  Future<void> saveCustom({required bool functional}) async {
    final now = DateTime.now();
    state = ConsentState(
      hasDecided: true,
      functionalEnabled: functional,
      status: 'custom',
      timestamp: now,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, 'custom');
      await prefs.setBool(_functionalKey, functional);
      await prefs.setString(_timestampKey, now.toIso8601String());
      if (!functional) {
        await prefs.remove('theme_preference');
        await prefs.remove('app_language_preference');
      }
    } catch (_) {}
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier();
});
