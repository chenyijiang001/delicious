import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shopping_item.dart';
import '../services/api_client.dart';

class ShoppingState {
  final List<ShoppingItem> items;
  final double totalCost;
  final int uncheckedCount;
  final bool isLoading;
  final String? errorMessage;

  const ShoppingState({
    this.items = const [],
    this.totalCost = 0,
    this.uncheckedCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  ShoppingState copyWith({
    List<ShoppingItem>? items,
    double? totalCost,
    int? uncheckedCount,
    bool? isLoading,
    String? errorMessage,
  }) =>
      ShoppingState(
        items: items ?? this.items,
        totalCost: totalCost ?? this.totalCost,
        uncheckedCount: uncheckedCount ?? this.uncheckedCount,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class ShoppingNotifier extends StateNotifier<ShoppingState> {
  final ApiClient _api;
  ShoppingNotifier(this._api) : super(const ShoppingState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.dio.get('/shopping/items');
      final data = res.data as Map<String, dynamic>;
      state = ShoppingState(
        items: (data['items'] as List)
            .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCost: (data['total_estimated_cost'] as num).toDouble(),
        uncheckedCount: (data['unchecked_count'] as num).toInt(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '加载失败');
    }
  }

  Future<(int, int)?> addFromFood(String foodId) async {
    try {
      final res = await _api.dio.post('/shopping/items/from-food',
          data: {'food_id': foodId});
      final data = res.data as Map<String, dynamic>;
      state = state.copyWith(
        items: (data['items'] as List)
            .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return (data['added_count'] as int, data['merged_count'] as int);
    } catch (_) {
      return null;
    }
  }

  Future<bool> addManual({
    required String name,
    required double amount,
    required String unit,
    required double estimatedPrice,
  }) async {
    try {
      await _api.dio.post('/shopping/items', data: {
        'name': name,
        'amount': amount,
        'unit': unit,
        'estimated_price': estimatedPrice,
      });
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleChecked(String id, bool checked) async {
    final idx = state.items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final updated = [...state.items];
    final old = updated[idx];
    updated[idx] = ShoppingItem(
      id: old.id,
      name: old.name,
      amount: old.amount,
      unit: old.unit,
      estimatedPrice: old.estimatedPrice,
      checked: checked,
      source: old.source,
      fromFoodIds: old.fromFoodIds,
      createdAt: old.createdAt,
      updatedAt: old.updatedAt,
    );
    state = state.copyWith(
      items: updated,
      uncheckedCount: updated.where((i) => !i.checked).length,
      totalCost: updated
          .where((i) => !i.checked)
          .fold<double>(0, (s, i) => s + i.estimatedPrice),
    );
    try {
      await _api.dio.patch('/shopping/items/$id', data: {'checked': checked});
    } catch (_) {
      // 回滚
      await load();
    }
  }

  Future<void> updateAmount(String id, double amount) async {
    try {
      await _api.dio.patch('/shopping/items/$id', data: {'amount': amount});
      await load();
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    try {
      await _api.dio.delete('/shopping/items/$id');
      state = state.copyWith(
        items: state.items.where((i) => i.id != id).toList(),
      );
      await load();
    } catch (_) {}
  }

  Future<int> clearChecked() async {
    try {
      final res = await _api.dio.post('/shopping/clear-checked');
      await load();
      return (res.data['deleted_count'] as num).toInt();
    } catch (_) {
      return 0;
    }
  }

  Future<String?> exportText() async {
    try {
      final res = await _api.dio.get('/shopping/export',
          queryParameters: {'format': 'text'});
      return res.data['text'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final shoppingProvider =
    StateNotifierProvider<ShoppingNotifier, ShoppingState>((ref) {
  return ShoppingNotifier(ref.watch(apiClientProvider));
});
