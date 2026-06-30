import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String code; // 后端约定的机器可读码
  final String message;

  ApiException({this.statusCode, required this.code, required this.message});

  bool get isDuplicateHint => statusCode == 200 && code == 'duplicate_hint';
  bool get isNoFood => statusCode == 422 && code == 'no_food_detected';
  bool get isUpstream => statusCode == 502;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiClient {
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(_translate(error));
      },
    ));
  }

  static String _baseUrl() {
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
    return 'http://localhost:8000/api/v1';
  }

  DioException _translate(DioException error) {
    final response = error.response;
    String code = 'network_error';
    String message = '网络错误，请重试';
    if (response != null) {
      message = '请求失败 (${response.statusCode})';
      final data = response.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          code = (detail['code'] as String?) ?? code;
          message = (detail['detail'] as String?) ?? message;
        } else if (detail is String) {
          message = detail;
        }
      }
    }
    final api = ApiException(
      statusCode: response?.statusCode,
      code: code,
      message: message,
    );
    return error.copyWith(error: api, message: message);
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: 'access_token', value: token);

  Future<void> clearToken() => _storage.delete(key: 'access_token');

  Future<String?> getToken() => _storage.read(key: 'access_token');
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
