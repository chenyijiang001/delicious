import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cost_stats.dart';
import '../providers/stats_provider.dart';

class CostPanelScreen extends ConsumerStatefulWidget {
  const CostPanelScreen({super.key});

  @override
  ConsumerState<CostPanelScreen> createState() => _CostPanelScreenState();
}

class _CostPanelScreenState extends ConsumerState<CostPanelScreen> {
  String _range = 'week';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = ref.watch(costStatsProvider(_range));

    return Scaffold(
      appBar: AppBar(title: const Text('成本面板')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('加载失败')),
        data: (s) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(costStatsProvider(_range).future).then((_) {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _rangeToggle(theme),
              const SizedBox(height: 16),
              _summary(s, theme),
              const SizedBox(height: 24),
              _byDayChart(s, theme),
              const SizedBox(height: 24),
              if (s.topExpensive.isNotEmpty) ...[
                _sectionTitle('最贵的菜', theme),
                ...s.topExpensive.map((it) => _topRow(it, theme, true)),
                const SizedBox(height: 16),
              ],
              if (s.topCheap.isNotEmpty && s.topCheap.first.foodId != s.topExpensive.firstOrNull?.foodId) ...[
                _sectionTitle('最便宜的菜', theme),
                ...s.topCheap.map((it) => _topRow(it, theme, false)),
                const SizedBox(height: 16),
              ],
              if (s.byCategory.isNotEmpty) ...[
                _sectionTitle('按分类占比', theme),
                _byCategory(s, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rangeToggle(ThemeData theme) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'week', label: Text('本周')),
        ButtonSegment(value: 'month', label: Text('本月')),
      ],
      selected: {_range},
      onSelectionChanged: (s) => setState(() => _range = s.first),
    );
  }

  Widget _summary(CostStats s, ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.start} ~ ${s.end}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('¥${s.totalCost.toStringAsFixed(1)}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                )),
            const SizedBox(height: 4),
            Text('共 ${s.recordCount} 道菜 · 平均每餐 ¥${s.avgPerMeal.toStringAsFixed(1)}',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _byDayChart(CostStats s, ThemeData theme) {
    final maxCost =
        s.byDay.fold<double>(0, (m, d) => d.cost > m ? d.cost : m);
    if (maxCost == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('每日花费', theme),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: s.byDay.map((d) {
                  final ratio = d.cost / maxCost;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            d.cost > 0 ? d.cost.toStringAsFixed(0) : '',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: ratio * 80 + (d.cost > 0 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: d.cost > 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.date.substring(d.date.length - 2),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, ThemeData theme) {
    return Text(t,
        style: theme.textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w600));
  }

  Widget _topRow(CostItemBrief it, ThemeData theme, bool expensive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(
          expensive ? Icons.trending_up : Icons.trending_down,
          color: expensive ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(it.dishName),
        trailing: Text('¥${it.cost.toStringAsFixed(1)}',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _byCategory(CostStats s, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: s.byCategory.map((c) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c.category)),
                      Text('¥${c.cost.toStringAsFixed(1)} · ${(c.ratio * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.ratio.clamp(0, 1),
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
