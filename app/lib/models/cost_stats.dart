class CostItemBrief {
  final String foodId;
  final String dishName;
  final double cost;

  const CostItemBrief(
      {required this.foodId, required this.dishName, required this.cost});

  factory CostItemBrief.fromJson(Map<String, dynamic> j) => CostItemBrief(
        foodId: j['food_id'] as String,
        dishName: j['dish_name'] as String,
        cost: (j['cost'] as num).toDouble(),
      );
}

class CostByCategory {
  final String category;
  final double cost;
  final double ratio;

  const CostByCategory(
      {required this.category, required this.cost, required this.ratio});

  factory CostByCategory.fromJson(Map<String, dynamic> j) => CostByCategory(
        category: j['category'] as String,
        cost: (j['cost'] as num).toDouble(),
        ratio: (j['ratio'] as num).toDouble(),
      );
}

class CostByDay {
  final String date;
  final double cost;

  const CostByDay({required this.date, required this.cost});

  factory CostByDay.fromJson(Map<String, dynamic> j) => CostByDay(
        date: j['date'] as String,
        cost: (j['cost'] as num).toDouble(),
      );
}

class CostStats {
  final String range;
  final String start;
  final String end;
  final double totalCost;
  final int recordCount;
  final double avgPerMeal;
  final List<CostItemBrief> topExpensive;
  final List<CostItemBrief> topCheap;
  final List<CostByCategory> byCategory;
  final List<CostByDay> byDay;

  const CostStats({
    required this.range,
    required this.start,
    required this.end,
    required this.totalCost,
    required this.recordCount,
    required this.avgPerMeal,
    required this.topExpensive,
    required this.topCheap,
    required this.byCategory,
    required this.byDay,
  });

  factory CostStats.fromJson(Map<String, dynamic> j) => CostStats(
        range: j['range'] as String,
        start: j['start'] as String,
        end: j['end'] as String,
        totalCost: (j['total_cost'] as num).toDouble(),
        recordCount: (j['record_count'] as num).toInt(),
        avgPerMeal: (j['avg_per_meal'] as num).toDouble(),
        topExpensive: (j['top_expensive'] as List)
            .map((e) => CostItemBrief.fromJson(e as Map<String, dynamic>))
            .toList(),
        topCheap: (j['top_cheap'] as List)
            .map((e) => CostItemBrief.fromJson(e as Map<String, dynamic>))
            .toList(),
        byCategory: (j['by_category'] as List)
            .map((e) => CostByCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        byDay: (j['by_day'] as List)
            .map((e) => CostByDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
