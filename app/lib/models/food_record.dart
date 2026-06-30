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
  final DateTime cookedAt;
  final String source; // recognize | manual | duplicate
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
    required this.cookedAt,
    this.source = 'recognize',
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    final cookedAtStr = json['cooked_at'] as String?;
    final created = DateTime.parse(json['created_at'] as String);
    return FoodRecord(
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
      totalCost:
          json['total_cost'] != null ? (json['total_cost'] as num).toDouble() : null,
      servingSize: (json['serving_size'] as num?)?.toInt() ?? 1,
      difficulty: json['difficulty'] as String? ?? '中等',
      tips: json['tips'] != null ? List<String>.from(json['tips'] as List) : [],
      notes: json['notes'] as String?,
      cookedAt: cookedAtStr != null ? DateTime.parse(cookedAtStr) : created,
      source: (json['source'] as String?) ?? 'recognize',
      createdAt: created,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

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
    DateTime? cookedAt,
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
        cookedAt: cookedAt ?? this.cookedAt,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toCreateJson() => {
        'image_url': imageUrl,
        'thumbnail_url': thumbnailUrl,
        'dish_name': dishName,
        'category': category,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'total_cost': totalCost,
        'serving_size': servingSize,
        'difficulty': difficulty,
        'tips': tips,
        'notes': notes,
        'cooked_at':
            '${cookedAt.year.toString().padLeft(4, '0')}-${cookedAt.month.toString().padLeft(2, '0')}-${cookedAt.day.toString().padLeft(2, '0')}',
        'source': source,
      };
}
