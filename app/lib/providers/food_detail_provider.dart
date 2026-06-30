import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_record.dart';
import '../models/recipe.dart';
import '../services/api_client.dart';

enum DetailStatus { loading, loaded, saving, error }

class FoodDetailState {
  final DetailStatus status;
  final FoodRecord? record;
  final String? errorMessage;

  const FoodDetailState(
      {this.status = DetailStatus.loading, this.record, this.errorMessage});

  FoodDetailState copyWith(
          {DetailStatus? status, FoodRecord? record, String? errorMessage}) =>
      FoodDetailState(
        status: status ?? this.status,
        record: record ?? this.record,
        errorMessage: errorMessage,
      );
}

class FoodDetailNotifier extends StateNotifier<FoodDetailState> {
  final ApiClient _api;

  FoodDetailNotifier(this._api) : super(const FoodDetailState());

  Future<void> load(String id) async {
    state = state.copyWith(status: DetailStatus.loading);
    try {
      final res = await _api.dio.get('/foods/$id');
      state = FoodDetailState(
        status: DetailStatus.loaded,
        record: FoodRecord.fromJson(res.data as Map<String, dynamic>),
      );
    } catch (_) {
      state = const FoodDetailState(
          status: DetailStatus.error, errorMessage: '加载失败');
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _api.dio.delete('/foods/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<FoodRecord?> duplicate(String id, {int? servingSize}) async {
    try {
      final res = await _api.dio.post(
        '/foods/$id/duplicate',
        data: {if (servingSize != null) 'serving_size': servingSize},
      );
      return FoodRecord.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

final foodDetailProvider = StateNotifierProvider.family<FoodDetailNotifier,
    FoodDetailState, String>(
  (ref, id) => FoodDetailNotifier(ref.watch(apiClientProvider)),
);

/// 从 AI 识别结果构造一条暂存 FoodRecord，用于 recipe_editor 页编辑。
FoodRecord recipeToRecord(Recipe recipe, {String id = 'new'}) {
  final now = DateTime.now();
  return FoodRecord(
    id: id,
    imageUrl: recipe.imageUrl,
    thumbnailUrl: recipe.thumbnailUrl,
    dishName: recipe.dishName,
    category: recipe.category,
    ingredients: recipe.ingredients,
    steps: recipe.steps,
    totalCost: recipe.totalCost,
    servingSize: recipe.servingSize,
    difficulty: recipe.difficulty,
    tips: recipe.tips,
    cookedAt: DateTime(now.year, now.month, now.day),
    source: 'recognize',
    createdAt: now,
    updatedAt: now,
  );
}
