import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized storage for the JWT auth token.
///
/// Uses `flutter_secure_storage` (Keychain on iOS, Keystore-backed
/// EncryptedSharedPreferences on Android) instead of plain
/// `SharedPreferences`, since a stolen/leaked device backup or a rooted
/// device can read SharedPreferences values as plaintext.
///
/// Note: on Flutter web there is no OS-level secure enclave, so
/// flutter_secure_storage falls back to window.localStorage there — this
/// class still routes web through the same API for consistency, but the
/// real security benefit is on Android/iOS/desktop.
///
/// Includes a one-time migration: anyone who logged in before this change
/// has their token sitting in the old `jwt_token` SharedPreferences key.
/// The first read moves it into secure storage and wipes the old copy, so
/// existing users aren't silently logged out by this change.
class TokenStorage {
  TokenStorage._();

  static const _secureKey = 'jwt_token';
  static const _legacyPrefsKey = 'jwt_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> getToken() async {
    final secureValue = await _storage.read(key: _secureKey);
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    // One-time migration from the old plaintext SharedPreferences token.
    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(_legacyPrefsKey);
    if (legacyValue != null && legacyValue.isNotEmpty) {
      await _storage.write(key: _secureKey, value: legacyValue);
      await prefs.remove(_legacyPrefsKey);
      return legacyValue;
    }

    return null;
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _secureKey, value: token);
    // Clean up the legacy plaintext copy if one still exists from before
    // this change, so the token isn't left readable in two places.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_legacyPrefsKey)) {
      await prefs.remove(_legacyPrefsKey);
    }
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _secureKey);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_legacyPrefsKey)) {
      await prefs.remove(_legacyPrefsKey);
    }
  }
}