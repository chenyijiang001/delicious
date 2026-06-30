import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/stats_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final stats = ref.watch(costStatsProvider('week'));
    final theme = Theme.of(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(costStatsProvider('week').future).then((_) {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user?.nickname.characters.firstOrNull ?? '?',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.nickname ?? '未登录',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(user?.email ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 本周成本卡片
            _CostCard(stats: stats),
            const SizedBox(height: 16),

            _sectionTitle(context, '工具'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shopping_basket_outlined),
                    title: const Text('购物清单'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/shopping'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.local_offer_outlined),
                    title: const Text('我的价格表'),
                    subtitle: const Text('记录常用食材价格，让 AI 估算更准'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/prices'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle(context, '账号'),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text('退出登录',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () => _confirmLogout(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              )),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后未保存的草稿可能会丢失，确定要退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认退出')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }
}

class _CostCard extends StatelessWidget {
  final AsyncValue stats;
  const _CostCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => context.push('/cost'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: stats.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const Text('成本数据加载失败'),
            data: (s) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('本周烹饪开销',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text('¥${s.totalCost.toStringAsFixed(1)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          s.recordCount > 0
                              ? '${s.recordCount} 道菜 · 平均 ¥${s.avgPerMeal.toStringAsFixed(1)}'
                              : '本周还没有记录',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onPrimaryContainer),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
