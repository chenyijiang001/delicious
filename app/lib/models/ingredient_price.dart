class IngredientPrice {
  final String id;
  final String name;
  final String unit;
  final double unitPrice;
  final DateTime lastUsedAt;
  final String source; // user_edit | user_confirm

  const IngredientPrice({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.lastUsedAt,
    required this.source,
  });

  factory IngredientPrice.fromJson(Map<String, dynamic> json) => IngredientPrice(
        id: json['id'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String? ?? '',
        unitPrice: (json['unit_price'] as num).toDouble(),
        lastUsedAt: DateTime.parse(json['last_used_at'] as String),
        source: json['source'] as String? ?? 'user_edit',
      );
}
