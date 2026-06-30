import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool needsOnboarding;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.needsOnboarding = false,
  });

  bool get isLoggedIn => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? needsOnboarding,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: errorMessage,
        needsOnboarding: needsOnboarding ?? this.needsOnboarding,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kOnboardingPending = 'onboarding_pending';

  AuthNotifier(this._authService) : super(const AuthState()) {
    _restorePendingOnboarding();
  }

  Future<void> _restorePendingOnboarding() async {
    // 如果注册后 App 被杀进程，重新登录时仍然能继续引导。
    final pending = await _storage.read(key: _kOnboardingPending);
    if (pending == '1' && mounted) {
      state = state.copyWith(needsOnboarding: true);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authService.login(email, password);
      // 登录命中：保留之前可能尚未完成的引导 flag
      final pending = await _storage.read(key: _kOnboardingPending);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        needsOnboarding: pending == '1',
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _extractError(e),
      );
    }
  }

  Future<void> register(String email, String nickname, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authService.register(email, nickname, password);
      await _storage.write(key: _kOnboardingPending, value: '1');
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        needsOnboarding: true,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _extractError(e),
      );
    }
  }

  Future<void> completeOnboarding() async {
    await _storage.delete(key: _kOnboardingPending);
    state = state.copyWith(needsOnboarding: false);
  }

  Future<void> logout() async {
    await _authService.logout();
    // 不清 onboarding_pending：用户可能只是切账号，下次回来仍需引导
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final api = e.error;
      if (api is ApiException) {
        if (api.statusCode == 409) return '该邮箱已注册';
        if (api.statusCode == 401) return '邮箱或密码错误';
        return api.message;
      }
    }
    return '网络错误，请重试';
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
