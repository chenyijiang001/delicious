import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/food_record.dart';
import '../providers/food_detail_provider.dart';
import '../providers/food_list_provider.dart';
import '../providers/shopping_provider.dart';
import '../widgets/ingredient_list.dart';
import '../widgets/recipe_steps.dart';
import '../widgets/share_card.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  final String foodId;
  const FoodDetailScreen({super.key, required this.foodId});

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(foodDetailProvider(widget.foodId).notifier).load(widget.foodId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodDetailProvider(widget.foodId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.record?.dishName ?? '详情'),
        actions: [
          if (state.record != null)
            PopupMenuButton<String>(
              onSelected: (action) => _onAction(action, state.record!),
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'share', child: Text('分享卡片')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
        ],
      ),
      body: _buildBody(context, state, theme),
      floatingActionButton:
          state.record == null ? null : _fab(state.record!, theme),
    );
  }

  // ---------- FAB：再做一次 ----------
  Widget _fab(FoodRecord r, ThemeData theme) {
    return FloatingActionButton.extended(
      onPressed: () => _duplicate(r),
      icon: const Icon(Icons.replay),
      label: const Text('再做一次'),
    );
  }

  Future<void> _duplicate(FoodRecord r) async {
    int serving = r.servingSize;
    final useNew = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('再做一次'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('要做几人份？'),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: serving > 1
                        ? () => setSt(() => serving -= 1)
                        : null,
                  ),
                  Expanded(
                    child: Center(
                      child: Text('$serving 人份',
                          style: Theme.of(ctx).textTheme.titleLarge),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setSt(() => serving += 1),
                  ),
                ],
              ),
              if (serving != r.servingSize)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('材料和成本会按比例自动调整',
                      style: Theme.of(ctx).textTheme.bodySmall),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('复制到今天')),
          ],
        ),
      ),
    );
    if (useNew != true) return;

    final created = await ref
        .read(foodDetailProvider(widget.foodId).notifier)
        .duplicate(widget.foodId, servingSize: serving);
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('复制失败')),
      );
      return;
    }
    ref.read(foodListProvider.notifier).loadFirst();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制到今天'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => context.push('/food/${created.id}'),
        ),
      ),
    );
  }

  // ---------- 顶栏菜单 ----------
  Future<void> _onAction(String action, FoodRecord r) async {
    switch (action) {
      case 'edit':
        context.push('/food/${widget.foodId}/edit', extra: {'record': r});
        break;
      case 'share':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => ShareCard(record: r),
        );
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('删除后无法恢复'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('删除')),
            ],
          ),
        );
        if (ok != true) return;
        final success = await ref
            .read(foodDetailProvider(widget.foodId).notifier)
            .delete(widget.foodId);
        if (!mounted) return;
        if (success) {
          ref.read(foodListProvider.notifier).removeFromList(widget.foodId);
          context.pop();
        }
        break;
    }
  }

  // ---------- 主体 ----------
  Widget _buildBody(BuildContext context, FoodDetailState state, ThemeData theme) {
    if (state.status == DetailStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null || state.record == null) {
      return Center(child: Text(state.errorMessage ?? '加载失败'));
    }
    final r = state.record!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                r.imageUrl!,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(r.dishName,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Chip(label: Text(r.category)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${DateFormat('yyyy-MM-dd').format(r.cookedAt)} 制作',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoLabel(context, '${r.servingSize}人份'),
              const SizedBox(width: 8),
              _infoLabel(context, r.difficulty),
              if (r.totalCost != null) ...[
                const SizedBox(width: 8),
                _infoLabel(context, '¥${r.totalCost!.toStringAsFixed(1)}'),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 行动按钮：加入购物清单
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addToShopping(r),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('加入购物清单'),
            ),
          ),
          const SizedBox(height: 16),

          if (r.notes != null && r.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.notes!, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 16),
          ],

          Text('耗材清单',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          IngredientList(ingredients: r.ingredients),
          const SizedBox(height: 24),

          Text('制作步骤',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RecipeSteps(steps: r.steps),
          const SizedBox(height: 24),

          if (r.tips.isNotEmpty) ...[
            Text('小贴士',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...r.tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 '),
                      Expanded(child: Text(t)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _addToShopping(FoodRecord r) async {
    final result =
        await ref.read(shoppingProvider.notifier).addFromFood(widget.foodId);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入失败')),
      );
      return;
    }
    final (added, merged) = result;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入：新增 $added 项，合并 $merged 项'),
        action: SnackBarAction(
          label: '查看清单',
          onPressed: () => context.push('/shopping'),
        ),
      ),
    );
  }

  Widget _infoLabel(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
