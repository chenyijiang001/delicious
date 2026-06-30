import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_record.dart';
import '../services/api_client.dart';

class FoodListState {
  final List<FoodRecord> items;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? errorMessage;
  final String? searchQuery;
  final String? categoryFilter;
  final String? ingredientFilter;

  const FoodListState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 0,
    this.errorMessage,
    this.searchQuery,
    this.categoryFilter,
    this.ingredientFilter,
  });

  FoodListState copyWith({
    List<FoodRecord>? items,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? errorMessage,
    String? searchQuery,
    String? categoryFilter,
    String? ingredientFilter,
  }) =>
      FoodListState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        errorMessage: errorMessage,
        searchQuery: searchQuery ?? this.searchQuery,
        categoryFilter: categoryFilter ?? this.categoryFilter,
        ingredientFilter: ingredientFilter ?? this.ingredientFilter,
      );
}

class FoodListNotifier extends StateNotifier<FoodListState> {
  final ApiClient _api;

  FoodListNotifier(this._api) : super(const FoodListState());

  Future<void> loadFirst() async {
    state = state.copyWith(isLoading: true, items: [], page: 0, hasMore: true);
    await _loadPage(1);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await _loadPage(state.page + 1);
  }

  Future<void> refresh() => loadFirst();

  Future<void> search(String query, {String mode = 'dish'}) async {
    // 直接构造新 state，避免 copyWith fallback 导致无法清空搜索词
    final q = query.isEmpty ? null : query;
    state = FoodListState(
      categoryFilter: state.categoryFilter,
      searchQuery: mode == 'dish' ? q : null,
      ingredientFilter: mode == 'ingredient' ? q : null,
    );
    await loadFirst();
  }

  Future<void> filterCategory(String? category) async {
    state = FoodListState(
      categoryFilter: category,
      searchQuery: state.searchQuery,
      ingredientFilter: state.ingredientFilter,
    );
    await loadFirst();
  }

  Future<void> _loadPage(int page) async {
    state = state.copyWith(isLoading: true);

    try {
      final params = <String, dynamic>{'page': page, 'size': 20};
      if (state.searchQuery != null) params['q'] = state.searchQuery;
      if (state.categoryFilter != null) params['category'] = state.categoryFilter;
      if (state.ingredientFilter != null) params['ingredient'] = state.ingredientFilter;

      final res = await _api.dio.get('/foods', queryParameters: params);
      final data = res.data;

      final items = (data['items'] as List)
          .map((e) => FoodRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        items: page == 1 ? items : [...state.items, ...items],
        isLoading: false,
        page: page,
        hasMore: items.length >= 20,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载失败: ${e.toString()}',
      );
    }
  }

  void removeFromList(String foodId) {
    state = state.copyWith(
      items: state.items.where((f) => f.id != foodId).toList(),
    );
  }
}

final foodListProvider =
    StateNotifierProvider<FoodListNotifier, FoodListState>((ref) {
  return FoodListNotifier(ref.watch(apiClientProvider));
});
