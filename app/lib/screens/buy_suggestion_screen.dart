import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/buy_suggestion.dart';
import '../providers/buy_suggestion_provider.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';

class BuySuggestionScreen extends ConsumerStatefulWidget {
  const BuySuggestionScreen({super.key});

  @override
  ConsumerState<BuySuggestionScreen> createState() =>
      _BuySuggestionScreenState();
}

class _BuySuggestionScreenState extends ConsumerState<BuySuggestionScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(analyticsProvider).log('buy_suggest_open');
      ref.read(buySuggestionProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buySuggestionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('看看去哪买'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '附近超市'),
            Tab(text: '配送到家'),
            Tab(text: '外卖买菜'),
          ],
        ),
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(BuySuggestionState state, ThemeData theme) {
    switch (state.status) {
      case BuySuggestionStatus.idle:
      case BuySuggestionStatus.locating:
        return _loading('正在获取位置...');
      case BuySuggestionStatus.loading:
        return _loading('AI 正在思考最优组合...');
      case BuySuggestionStatus.locationDenied:
        return _locationDenied(state.denialReason, theme);
      case BuySuggestionStatus.error:
        return _errorView(state.errorMessage, theme);
      case BuySuggestionStatus.loaded:
        return _loaded(state.data!, theme);
    }
  }

  // ---------- States ----------

  Widget _loading(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text),
        ],
      ),
    );
  }

  Widget _locationDenied(LocationDenialReason? reason, ThemeData theme) {
    final isForever = reason == LocationDenialReason.permissionDeniedForever;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            isForever ? '定位权限被永久拒绝' : '需要位置才能推荐附近店铺',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isForever
                ? '请到系统设置 → Delicious → 位置 中开启'
                : '我们只在本次推荐时使用你的位置，不会存储',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              ref.read(analyticsProvider).log('location_prompt', {
                'result': 'retry',
              });
              ref.read(buySuggestionProvider.notifier).load();
            },
            child: const Text('重新获取定位'),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String? msg, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 56, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(msg ?? '获取失败'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                ref.read(buySuggestionProvider.notifier).load(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _loaded(BuySuggestion data, ThemeData theme) {
    return Column(
      children: [
        if (data.aiSuggestion != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.aiSuggestion!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _offlineTab(data.offline, theme),
              _platformTab(data.online, theme, emptyHint: '附近暂无可配送到家的平台'),
              _platformTab(data.delivery, theme, emptyHint: '附近暂无可叫的外卖买菜'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Offline ----------

  Widget _offlineTab(List<OfflineBlock> blocks, ThemeData theme) {
    if (blocks.isEmpty) {
      return _emptyHint('附近没找到合适的店，试试「配送到家」', theme);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: blocks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _offlineCard(blocks[i], theme),
    );
  }

  Widget _offlineCard(OfflineBlock b, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _onOfflineTap(b),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(b.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(b.displayDistance,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _tag(theme, b.categoryLabel),
                  const SizedBox(width: 6),
                  _coverageTag(b.coverage, theme),
                  const Spacer(),
                  Text('约 ¥${b.estimatedCost.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
              if (b.coverage.missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '缺：${b.coverage.missing.join("、")}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (b.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(b.address,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onOfflineTap(OfflineBlock b) async {
    ref.read(analyticsProvider).log('buy_suggest_click', {
      'channel': 'offline',
      'target': b.poiId,
      'missing': b.coverage.missing.length,
    });
    await ref.read(buySuggestionProvider.notifier).reportClick(
          channel: 'offline',
          target: b.poiId,
          missingCount: b.coverage.missing.length,
        );
    await _launch(b.navigateUrl, b.navigateUrl);
  }

  // ---------- Online / Delivery ----------

  Widget _platformTab(
    List<PlatformBlock> blocks,
    ThemeData theme, {
    required String emptyHint,
  }) {
    if (blocks.isEmpty) return _emptyHint(emptyHint, theme);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: blocks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _platformCard(blocks[i], theme),
    );
  }

  Widget _platformCard(PlatformBlock b, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _onPlatformTap(b),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(b.platformName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text('约 ${b.estimatedEtaMinutes} 分钟达',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _coverageTag(b.coverage, theme),
                  const Spacer(),
                  Text('约 ¥${b.estimatedCost.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
              if (b.coverage.missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '可能缺：${b.coverage.missing.join("、")}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.open_in_new,
                      size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('打开 ${b.platformName}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPlatformTap(PlatformBlock b) async {
    // channel 来自后端权威（platform 配置里就标好了），不再用 ETA 猜
    ref.read(analyticsProvider).log('buy_suggest_click', {
      'channel': b.channel,
      'target': b.platform,
      'missing': b.coverage.missing.length,
    });
    await ref.read(buySuggestionProvider.notifier).reportClick(
          channel: b.channel,
          target: b.platform,
          missingCount: b.coverage.missing.length,
        );
    await _launch(b.scheme, b.webFallback);
  }

  // ---------- atoms ----------

  Widget _coverageTag(Coverage c, ThemeData theme) {
    final color = c.isFull
        ? theme.colorScheme.primary
        : (c.ratio >= 0.6 ? Colors.orange : theme.colorScheme.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        c.isFull ? '全部 ${c.total} 项' : '${c.matched}/${c.total} 项',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tag(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }

  Widget _emptyHint(String text, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ---------- deeplink ----------

  Future<void> _launch(String primary, String fallback) async {
    try {
      final uri = Uri.parse(primary);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    try {
      await launchUrl(Uri.parse(fallback),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打不开链接，请检查网络')),
        );
      }
    }
  }
}
