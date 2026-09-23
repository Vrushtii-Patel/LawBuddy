import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

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

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  // `clearError` is a separate flag (rather than relying on passing
  // `errorMessage: null`) because `errorMessage ?? this.errorMessage` can
  // never actually null out the field — `null` just falls back to the old
  // value. Pass `clearError: true` whenever the previous error should be
  // dropped (e.g. after a successful call), instead of `errorMessage: null`.
  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token != null && token.isNotEmpty) {
        final data = await ApiService.getProfile(token);
        final user = UserModel.fromJson(data['user']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearError: true,
      );
    }
  }

  Future<bool> sendOtp({
    required String email,
    required String type,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await ApiService.sendOtp(
        email: email,
        type: type,
      );
      state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String otp,
    required String type,
    String? fullName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final data = await ApiService.verifyOtp(
        email: email,
        otp: otp,
        type: type,
        fullName: fullName,
      );
      
      final user = UserModel.fromJson(data['user']);
      final String token = data['token'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('userId', user.userId); // Kept for legacy compatibility if needed
      
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> resendOtp(String email) async {
    try {
      await ApiService.resendOtp(email);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
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
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('userId');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        errorMessage: 'Failed to logout',
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});