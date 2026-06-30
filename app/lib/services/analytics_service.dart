import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 客户端埋点：本地缓冲，每 30s 或 50 条 flush 一次。
/// 失败保留在内存，下次合并。失败超 200 条则丢弃最旧的（避免无限增长）。
class AnalyticsService {
  final ApiClient _api;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;

  AnalyticsService(this._api) {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void log(String name, [Map<String, dynamic>? props]) {
    _queue.add({
      'name': name,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'props': props ?? {},
    });
    if (_queue.length >= 50) flush();
    if (_queue.length > 200) {
      _queue.removeRange(0, _queue.length - 200);
    }
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      await _api.dio.post('/events', data: {'events': batch});
    } catch (_) {
      // 失败回填，等下次重试
      _queue.insertAll(0, batch);
    }
  }

  void dispose() {
    _timer?.cancel();
    flush();
  }
}

final analyticsProvider = Provider<AnalyticsService>((ref) {
  final svc = AnalyticsService(ref.watch(apiClientProvider));
  ref.onDispose(svc.dispose);
  return svc;
});
