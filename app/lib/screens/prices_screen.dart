import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/ingredient_price.dart';
import '../providers/price_provider.dart';

class PricesScreen extends ConsumerStatefulWidget {
  const PricesScreen({super.key});

  @override
  ConsumerState<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends ConsumerState<PricesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(priceProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('我的价格表')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              '记录常用食材的真实价格，下次 AI 识别时会自动用你的价格替换估算',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: state.items.isEmpty && !state.isLoading
                ? _empty(theme)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _row(state.items[i], theme),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('添加价格'),
      ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_outlined,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('还没有价格记录', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('修改 AI 估算的食材价格时会自动保存',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _row(IngredientPrice p, ThemeData theme) {
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        await ref.read(priceProvider.notifier).delete(p.id);
        return true;
      },
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(p.name),
          subtitle: Text(
              '¥${p.unitPrice.toStringAsFixed(2)}/${p.unit.isEmpty ? "单位" : p.unit} · 上次使用 ${DateFormat('MM-dd').format(p.lastUsedAt.toLocal())}'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _showEditor(p),
        ),
      ),
    );
  }

  Future<void> _showEditor(IngredientPrice? p) async {
    final nameCtrl = TextEditingController(text: p?.name ?? '');
    final unitCtrl = TextEditingController(text: p?.unit ?? '');
    final priceCtrl = TextEditingController(text: p?.unitPrice.toString() ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p == null ? '添加价格' : '编辑价格',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: '食材名（如番茄、鸡蛋）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '单价(元)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                        labelText: '单位', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                  if (name.isEmpty || price <= 0) {
                    Navigator.pop(ctx, false);
                    return;
                  }
                  final success = await ref
                      .read(priceProvider.notifier)
                      .upsert(name, unitCtrl.text.trim(), price);
                  if (ctx.mounted) Navigator.pop(ctx, success);
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }
}
