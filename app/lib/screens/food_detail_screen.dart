import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/food_detail_provider.dart';
import '../providers/food_list_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(state.record?.dishName ?? '详情'),
        actions: [
          if (state.record != null)
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  context.push('/food/${widget.foodId}/edit',
                      extra: state.record);
                } else if (action == 'delete') {
                  final confirmed = await showDialog<bool>(
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
                  if (confirmed == true) {
                    final ok = await ref
                        .read(foodDetailProvider(widget.foodId).notifier)
                        .delete(widget.foodId);
                    if (ok) {
                      ref.read(foodListProvider.notifier).removeFromList(widget.foodId);
                      if (mounted) context.pop();
                    }
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, FoodDetailState state) {
    if (state.status == DetailStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(child: Text(state.errorMessage!));
    }
    final record = state.record!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (record.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                record.imageUrl!,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Title row
          Row(
            children: [
              Expanded(
                child: Text(record.dishName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Chip(label: Text(record.category)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoLabel(context, '${record.servingSize}人份'),
              const SizedBox(width: 8),
              _infoLabel(context, record.difficulty),
              if (record.totalCost != null) ...[
                const SizedBox(width: 8),
                _infoLabel(context, '¥${record.totalCost!.toStringAsFixed(1)}'),
              ],
            ],
          ),
          const SizedBox(height: 24),

          if (record.notes != null && record.notes!.isNotEmpty) ...[
            Text(record.notes!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],

          // Ingredients
          Text('耗材清单',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          IngredientList(ingredients: record.ingredients),
          const SizedBox(height: 24),

          // Steps
          Text('制作步骤',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RecipeSteps(steps: record.steps),
          const SizedBox(height: 24),

          // Tips
          if (record.tips.isNotEmpty) ...[
            Text('小贴士',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...record.tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 '),
                      Expanded(child: Text(t)),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // Share button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => ShareCard(record: record),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('分享美食卡片'),
            ),
          ),
          const SizedBox(height: 40),
        ],
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
