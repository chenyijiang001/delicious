class ShoppingItem {
  final String id;
  final String name;
  final double amount;
  final String unit;
  final double estimatedPrice;
  final bool checked;
  final String source; // auto | manual
  final List<String> fromFoodIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.estimatedPrice,
    required this.checked,
    required this.source,
    required this.fromFoodIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String? ?? '',
        estimatedPrice: (json['estimated_price'] as num).toDouble(),
        checked: json['checked'] as bool,
        source: json['source'] as String,
        fromFoodIds: (json['from_food_ids'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
