import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<User> register(String email, String nickname, String password) async {
    final res = await _api.dio.post('/auth/register', data: {
      'email': email,
      'nickname': nickname,
      'password': password,
    });
    await _api.saveToken(res.data['access_token'] as String);
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  Future<User> login(String email, String password) async {
    final res = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _api.saveToken(res.data['access_token'] as String);
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _api.clearToken();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});
