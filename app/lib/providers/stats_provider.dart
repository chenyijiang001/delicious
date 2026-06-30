import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cost_stats.dart';
import '../services/api_client.dart';

final costStatsProvider =
    FutureProvider.family<CostStats, String>((ref, range) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/stats/cost', queryParameters: {'range': range});
  return CostStats.fromJson(res.data as Map<String, dynamic>);
});
