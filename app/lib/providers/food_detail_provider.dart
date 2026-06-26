import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_record.dart';
import '../models/recipe.dart';
import '../services/api_client.dart';

enum DetailStatus { loading, loaded, saving, error }

class FoodDetailState {
  final DetailStatus status;
  final FoodRecord? record;
  final String? errorMessage;

  const FoodDetailState({this.status = DetailStatus.loading, this.record, this.errorMessage});

  FoodDetailState copyWith({DetailStatus? status, FoodRecord? record, String? errorMessage}) =>
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
    } catch (e) {
      state = FoodDetailState(status: DetailStatus.error, errorMessage: '加载失败');
    }
  }

  Future<bool> save(FoodRecord record) async {
    state = state.copyWith(status: DetailStatus.saving);
    try {
      final body = <String, dynamic>{
        'image_url': record.imageUrl,
        'thumbnail_url': record.thumbnailUrl,
        'dish_name': record.dishName,
        'category': record.category,
        'ingredients': record.ingredients.map((i) => i.toJson()).toList(),
        'steps': record.steps.map((s) => s.toJson()).toList(),
        'total_cost': record.totalCost,
        'serving_size': record.servingSize,
        'difficulty': record.difficulty,
        'tips': record.tips,
        'notes': record.notes,
      };

      if (record.id == 'new') {
        final res = await _api.dio.post('/foods', data: body);
        state = FoodDetailState(
          status: DetailStatus.loaded,
          record: FoodRecord.fromJson(res.data as Map<String, dynamic>),
        );
        return true;
      } else {
        final res = await _api.dio.put('/foods/${record.id}', data: body);
        state = FoodDetailState(
          status: DetailStatus.loaded,
          record: FoodRecord.fromJson(res.data as Map<String, dynamic>),
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        status: DetailStatus.error,
        errorMessage: '保存失败: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _api.dio.delete('/foods/$id');
      return true;
    } catch (e) {
      return false;
    }
  }
}

final foodDetailProvider = StateNotifierProvider.family<FoodDetailNotifier, FoodDetailState, String>(
  (ref, id) => FoodDetailNotifier(ref.watch(apiClientProvider)),
);

/// Create a new record from AI result
FoodRecord recipeToRecord(Recipe recipe, {String id = 'new'}) {
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
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
