import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_price.dart';
import '../services/api_client.dart';

class PriceState {
  final List<IngredientPrice> items;
  final bool isLoading;
  final String? errorMessage;

  const PriceState(
      {this.items = const [], this.isLoading = false, this.errorMessage});

  PriceState copyWith(
          {List<IngredientPrice>? items,
          bool? isLoading,
          String? errorMessage}) =>
      PriceState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class PriceNotifier extends StateNotifier<PriceState> {
  final ApiClient _api;
  PriceNotifier(this._api) : super(const PriceState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.dio.get('/user/ingredient-prices');
      final items = (res.data['items'] as List)
          .map((e) => IngredientPrice.fromJson(e as Map<String, dynamic>))
          .toList();
      state = PriceState(items: items);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: '加载失败');
    }
  }

  Future<bool> upsert(String name, String unit, double unitPrice) async {
    try {
      await _api.dio.post('/user/ingredient-prices', data: {
        'name': name,
        'unit': unit,
        'unit_price': unitPrice,
      });
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _api.dio.delete('/user/ingredient-prices/$id');
      state = state.copyWith(
        items: state.items.where((i) => i.id != id).toList(),
      );
    } catch (_) {}
  }
}

final priceProvider = StateNotifierProvider<PriceNotifier, PriceState>((ref) {
  return PriceNotifier(ref.watch(apiClientProvider));
});
