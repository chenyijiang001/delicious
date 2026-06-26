class Ingredient {
  final String name;
  final double amount;
  final String unit;
  final double estimatedPrice;

  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.estimatedPrice,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    unit: json['unit'] as String,
    estimatedPrice: (json['estimated_price'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'estimated_price': estimatedPrice,
  };

  Ingredient copyWith({String? name, double? amount, String? unit, double? estimatedPrice}) =>
      Ingredient(
        name: name ?? this.name,
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
        estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      );
}

class StepData {
  final int stepNum;
  final String description;
  final int durationMinutes;

  const StepData({
    required this.stepNum,
    required this.description,
    required this.durationMinutes,
  });

  factory StepData.fromJson(Map<String, dynamic> json) => StepData(
    stepNum: json['step_num'] as int,
    description: json['description'] as String,
    durationMinutes: (json['duration_minutes'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'step_num': stepNum,
    'description': description,
    'duration_minutes': durationMinutes,
  };

  StepData copyWith({int? stepNum, String? description, int? durationMinutes}) => StepData(
    stepNum: stepNum ?? this.stepNum,
    description: description ?? this.description,
    durationMinutes: durationMinutes ?? this.durationMinutes,
  );
}

class Recipe {
  final String dishName;
  final String category;
  final List<Ingredient> ingredients;
  final List<StepData> steps;
  final double totalCost;
  final int servingSize;
  final String difficulty;
  final List<String> tips;
  final String? imageUrl;
  final String? thumbnailUrl;

  const Recipe({
    required this.dishName,
    required this.category,
    required this.ingredients,
    required this.steps,
    required this.totalCost,
    required this.servingSize,
    required this.difficulty,
    required this.tips,
    this.imageUrl,
    this.thumbnailUrl,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    dishName: json['dish_name'] as String,
    category: json['category'] as String,
    ingredients: (json['ingredients'] as List)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList(),
    steps: (json['steps'] as List)
        .map((e) => StepData.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalCost: (json['total_cost'] as num).toDouble(),
    servingSize: (json['serving_size'] as num).toInt(),
    difficulty: json['difficulty'] as String,
    tips: List<String>.from(json['tips'] as List),
    imageUrl: json['image_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
  );
}
