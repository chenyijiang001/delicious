class Coverage {
  final int matched;
  final int total;
  final List<String> missing;

  const Coverage(
      {required this.matched, required this.total, required this.missing});

  double get ratio => total == 0 ? 0 : matched / total;
  bool get isFull => total > 0 && matched == total;

  factory Coverage.fromJson(Map<String, dynamic> j) => Coverage(
        matched: (j['matched'] as num).toInt(),
        total: (j['total'] as num).toInt(),
        missing: (j['missing'] as List?)?.cast<String>() ?? const [],
      );
}

class OfflineBlock {
  final String poiId;
  final String name;
  final String category;
  final int distanceM;
  final String address;
  final Coverage coverage;
  final double estimatedCost;
  final String navigateUrl;

  const OfflineBlock({
    required this.poiId,
    required this.name,
    required this.category,
    required this.distanceM,
    required this.address,
    required this.coverage,
    required this.estimatedCost,
    required this.navigateUrl,
  });

  factory OfflineBlock.fromJson(Map<String, dynamic> j) => OfflineBlock(
        poiId: j['poi_id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        distanceM: (j['distance_m'] as num).toInt(),
        address: j['address'] as String? ?? '',
        coverage: Coverage.fromJson(j['coverage'] as Map<String, dynamic>),
        estimatedCost: (j['estimated_cost'] as num).toDouble(),
        navigateUrl: j['navigate_url'] as String,
      );

  String get displayDistance => distanceM < 1000
      ? '${distanceM}m'
      : '${(distanceM / 1000).toStringAsFixed(1)}km';

  String get categoryLabel {
    switch (category) {
      case 'supermarket':
        return '超市';
      case 'convenience':
        return '便利店';
      case 'market':
        return '菜市场';
      case 'fresh':
        return '生鲜专卖';
      default:
        return category;
    }
  }
}

class PlatformBlock {
  final String platform;
  final String platformName;
  final Coverage coverage;
  final double estimatedCost;
  final int estimatedEtaMinutes;
  final String scheme;
  final String webFallback;

  const PlatformBlock({
    required this.platform,
    required this.platformName,
    required this.coverage,
    required this.estimatedCost,
    required this.estimatedEtaMinutes,
    required this.scheme,
    required this.webFallback,
  });

  factory PlatformBlock.fromJson(Map<String, dynamic> j) => PlatformBlock(
        platform: j['platform'] as String,
        platformName: j['platform_name'] as String,
        coverage: Coverage.fromJson(j['coverage'] as Map<String, dynamic>),
        estimatedCost: (j['estimated_cost'] as num).toDouble(),
        estimatedEtaMinutes: (j['estimated_eta_minutes'] as num).toInt(),
        scheme: j['scheme'] as String,
        webFallback: j['web_fallback'] as String,
      );
}

class BuySuggestion {
  final String? aiSuggestion;
  final int itemsTotal;
  final List<OfflineBlock> offline;
  final List<PlatformBlock> online;
  final List<PlatformBlock> delivery;

  const BuySuggestion({
    this.aiSuggestion,
    required this.itemsTotal,
    required this.offline,
    required this.online,
    required this.delivery,
  });

  factory BuySuggestion.fromJson(Map<String, dynamic> j) => BuySuggestion(
        aiSuggestion: j['ai_suggestion'] as String?,
        itemsTotal: (j['items_total'] as num).toInt(),
        offline: (j['offline'] as List? ?? [])
            .map((e) => OfflineBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
        online: (j['online'] as List? ?? [])
            .map((e) => PlatformBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
        delivery: (j['delivery'] as List? ?? [])
            .map((e) => PlatformBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
