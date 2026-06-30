import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../models/shopping_item.dart';
import '../providers/shopping_provider.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(shoppingProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shoppingProvider);
    final theme = Theme.of(context);
    final unchecked = state.items.where((i) => !i.checked).toList();
    final checked = state.items.where((i) => i.checked).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('购物清单'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (a) async {
              if (a == 'share') {
                final text =
                    await ref.read(shoppingProvider.notifier).exportText();
                if (text != null) {
                  await Share.share(text, subject: '购物清单');
                }
              } else if (a == 'clear') {
                final n = await ref.read(shoppingProvider.notifier).clearChecked();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已清空 $n 条已购')),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('分享给家人')),
              PopupMenuItem(value: 'clear', child: Text('清空已购')),
            ],
          ),
        ],
      ),
      body: state.items.isEmpty
          ? _empty(theme)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                if (unchecked.isNotEmpty) _buySuggestEntry(theme, unchecked.length),
                if (unchecked.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionLabel('待购买 (${unchecked.length})', theme),
                  ...unchecked.map((i) => _row(i, theme)),
                ],
                if (checked.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('已购买 (${checked.length})', theme),
                  ...checked.map((i) => _row(i, theme)),
                ],
              ],
            ),
      bottomNavigationBar: state.items.isEmpty ? null : _bottomBar(state, theme),
      floatingActionButton: FloatingActionButton(
        onPressed: _addManual,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_basket_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('购物清单还是空的', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('在食谱详情里点「加入购物清单」即可一键加入',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buySuggestEntry(ThemeData theme, int count) {
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => context.push('/shopping/buy'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.near_me,
                    size: 22, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('看看去哪买',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        )),
                    const SizedBox(height: 2),
                    Text('AI 根据 $count 项清单帮你选最近最划算的店',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(text,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.outline)),
    );
  }

  Widget _row(ShoppingItem item, ThemeData theme) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        await ref.read(shoppingProvider.notifier).delete(item.id);
        return true;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: CheckboxListTile(
          value: item.checked,
          onChanged: (v) => ref
              .read(shoppingProvider.notifier)
              .toggleChecked(item.id, v ?? false),
          title: Text(
            '${item.name} ${_fmtAmount(item.amount)}${item.unit}',
            style: TextStyle(
              decoration: item.checked ? TextDecoration.lineThrough : null,
              color: item.checked ? theme.colorScheme.outline : null,
            ),
          ),
          subtitle: Text('¥${item.estimatedPrice.toStringAsFixed(1)}'),
          controlAffinity: ListTileControlAffinity.leading,
          onLongPress: () => _editAmount(item),
        ),
      ),
    );
  }

  Widget _bottomBar(ShoppingState state, ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('待购 ${state.uncheckedCount} 项',
                      style: theme.textTheme.bodySmall),
                  Text('预计 ¥${state.totalCost.toStringAsFixed(1)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      )),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final text = await ref
                    .read(shoppingProvider.notifier)
                    .exportText();
                if (text != null) {
                  await Share.share(text, subject: '购物清单');
                }
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('分享'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAmount(ShoppingItem item) async {
    final ctrl = TextEditingController(text: _fmtAmount(item.amount));
    final ok = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('调整 ${item.name} 数量'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: item.unit),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
              child: const Text('确定')),
        ],
      ),
    );
    if (ok != null && ok > 0) {
      await ref.read(shoppingProvider.notifier).updateAmount(item.id, ok);
    }
  }

  Future<void> _addManual() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('手动添加', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: '食材', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '数量', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                        labelText: '单位', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '¥估价', border: OutlineInputBorder()),
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
                  if (name.isEmpty) {
                    Navigator.pop(ctx, false);
                    return;
                  }
                  final success =
                      await ref.read(shoppingProvider.notifier).addManual(
                            name: name,
                            amount: double.tryParse(amountCtrl.text) ?? 1,
                            unit: unitCtrl.text.trim(),
                            estimatedPrice:
                                double.tryParse(priceCtrl.text) ?? 0,
                          );
                  if (ctx.mounted) Navigator.pop(ctx, success);
                },
                child: const Text('加入清单'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入购物清单')),
      );
    }
  }

  String _fmtAmount(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
