import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? errorCode;

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.errorCode,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool clearUser = false,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  bool _isLoggingOut = false;

  AuthNotifier() : super(AuthState()) {
    ApiService.onUnauthorized = () {
      if (!_isLoggingOut) {
        logout();
      }
    };
    checkAuthStatus();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await TokenStorage.getToken();

      if (token != null && token.isNotEmpty) {
        final data = await ApiService.getProfile(token);
        final user = UserModel.fromJson(data['user']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, clearUser: true);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearError: true,
      );
    }
  }

  Future<bool> signup({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await ApiService.signup(
        fullName: fullName,
        email: email,
        password: password,
        acceptedTerms: acceptedTerms,
      );
      state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
      return true;
    } catch (e) {
      final message = _extractErrorMessage(e);
      final code = _extractErrorCode(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: message,
        errorCode: code,
      );
      return false;
    }
  }

  Future<bool> verifyEmail({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final data = await ApiService.verifyEmail(
        email: email,
        otp: otp,
      );

      final user = UserModel.fromJson(data['user']);
      final String token = data['token'];

      await TokenStorage.saveToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.userId);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
      );
      return true;
    } catch (e) {
      final message = _extractErrorMessage(e);
      final code = _extractErrorCode(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: message,
        errorCode: code,
      );
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final data = await ApiService.login(
        email: email,
        password: password,
      );

      final user = UserModel.fromJson(data['user']);
      final String token = data['token'];

      await TokenStorage.saveToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.userId);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
      );
      return true;
    } catch (e) {
      final message = _extractErrorMessage(e);
      final code = _extractErrorCode(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: message,
        errorCode: code,
      );
      return false;
    }
  }

  Future<bool> forgotPassword({
    required String email,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await ApiService.forgotPassword(email: email);
      state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
      return true;
    } catch (e) {
      final message = _extractErrorMessage(e);
      final code = _extractErrorCode(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: message,
        errorCode: code,
      );
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await ApiService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
      return true;
    } catch (e) {
      final message = _extractErrorMessage(e);
      final code = _extractErrorCode(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: message,
        errorCode: code,
      );
      return false;
    }
  }

  Future<bool> resendOtp({
    required String email,
    required String purpose, // 'signup' | 'reset'
  }) async {
    try {
      await ApiService.resendOtp(email: email, purpose: purpose);
      return true;
    } catch (e) {
      final message = _extractErrorMessage(e);
      final code = _extractErrorCode(e);
      state = state.copyWith(
        status: state.status,
        errorMessage: message,
        errorCode: code,
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? profilePhoto,
    String? preferredLanguage,
    String? dateOfBirth,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final data = await ApiService.updateProfile(
        fullName: fullName,
        profilePhoto: profilePhoto,
        preferredLanguage: preferredLanguage,
        dateOfBirth: dateOfBirth,
      );
      final updatedUser = UserModel.fromJson(data['user']);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: updatedUser,
        clearError: true,
      );
      return true;
    } catch (e) {
      final message = _extractErrorMessage(e);
      final code = _extractErrorCode(e);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: message,
        errorCode: code,
      );
      return false;
    }
  }

  void updateUserName(String newName) {
    if (state.user != null && newName.trim().isNotEmpty) {
      final updatedUser = state.user!.copyWith(fullName: newName.trim());
      state = state.copyWith(user: updatedUser);
    }
  }

  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await ApiService.logout(explicitToken: token);
        } catch (e) {
          debugPrint('Remote logout warning (continuing local logout): $e');
        }
      }
    } catch (e) {
      debugPrint('Error retrieving token during logout: $e');
    } finally {
      try {
        await TokenStorage.deleteToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('userId');
      } catch (_) {}
      _isLoggingOut = false;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearError: true,
      );
    }
  }

  String _extractErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  String? _extractErrorCode(dynamic error) {
    if (error is ApiException) {
      return error.code;
    }
    return null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});