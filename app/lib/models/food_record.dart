import 'recipe.dart';

class FoodRecord {
  final String id;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String dishName;
  final String category;
  final List<Ingredient> ingredients;
  final List<StepData> steps;
  final double? totalCost;
  final int servingSize;
  final String difficulty;
  final List<String> tips;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodRecord({
    required this.id,
    this.imageUrl,
    this.thumbnailUrl,
    required this.dishName,
    required this.category,
    required this.ingredients,
    required this.steps,
    this.totalCost,
    this.servingSize = 1,
    this.difficulty = '中等',
    this.tips = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) => FoodRecord(
    id: json['id'] as String,
    imageUrl: json['image_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
    dishName: json['dish_name'] as String,
    category: json['category'] as String,
    ingredients: (json['ingredients'] as List)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList(),
    steps: (json['steps'] as List)
        .map((e) => StepData.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalCost: json['total_cost'] != null ? (json['total_cost'] as num).toDouble() : null,
    servingSize: (json['serving_size'] as num?)?.toInt() ?? 1,
    difficulty: json['difficulty'] as String? ?? '中等',
    tips: json['tips'] != null ? List<String>.from(json['tips'] as List) : [],
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  FoodRecord copyWith({
    String? dishName,
    String? category,
    List<Ingredient>? ingredients,
    List<StepData>? steps,
    double? totalCost,
    int? servingSize,
    String? difficulty,
    List<String>? tips,
    String? notes,
  }) =>
      FoodRecord(
        id: id,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        dishName: dishName ?? this.dishName,
        category: category ?? this.category,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        totalCost: totalCost ?? this.totalCost,
        servingSize: servingSize ?? this.servingSize,
        difficulty: difficulty ?? this.difficulty,
        tips: tips ?? this.tips,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
