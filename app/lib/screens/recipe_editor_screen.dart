import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/food_record.dart';
import '../models/recipe.dart';
import '../providers/food_detail_provider.dart';
import '../providers/food_list_provider.dart';
import '../services/api_client.dart';

/// 合并的"AI 识别结果 / 编辑"页。
/// - 新记录：foodId == 'new'，从 [initialRecord] 或 [imageBytes] 装载
/// - 已存在：foodId 是真实 id，从详情接口加载
class RecipeEditorScreen extends ConsumerStatefulWidget {
  final String foodId;
  final FoodRecord? initialRecord;
  final Uint8List? imageBytes;

  const RecipeEditorScreen({
    super.key,
    required this.foodId,
    this.initialRecord,
    this.imageBytes,
  });

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  FoodRecord? _record;
  bool _saving = false;
  late final TextEditingController _notesCtrl;

  final _categories = ['家常菜', '烘焙', '饮品', '汤品', '小吃', '面食', '其他'];
  final _difficulties = ['简单', '中等', '困难'];

  bool get _isNew => widget.foodId == 'new';

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.initialRecord?.notes ?? '');
    if (_isNew && widget.initialRecord != null) {
      _record = widget.initialRecord;
    } else if (!_isNew) {
      Future.microtask(() async {
        await ref.read(foodDetailProvider(widget.foodId).notifier).load(widget.foodId);
        final st = ref.read(foodDetailProvider(widget.foodId));
        if (st.record != null && mounted) {
          setState(() => _record = st.record);
          _notesCtrl.text = st.record!.notes ?? '';
        }
      });
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _record;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '保存美食记录' : '编辑'),
        actions: [
          // 只在 AI 识别结果上显示反馈入口；手动填写的没必要反馈
          if (r != null && r.source == 'recognize')
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: '反馈识别不准',
              onPressed: () => _showFeedbackSheet(r),
            ),
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存到日记'),
              ),
            ),
        ],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imageHeader(r, theme),
                  const SizedBox(height: 16),
                  _dishNameRow(r, theme),
                  const SizedBox(height: 12),
                  _metaChips(r, theme),
                  const SizedBox(height: 24),
                  _ingredientsBlock(r, theme),
                  const SizedBox(height: 24),
                  _stepsBlock(r, theme),
                  const SizedBox(height: 24),
                  _tipsBlock(r, theme),
                  const SizedBox(height: 24),
                  _notesField(r),
                ],
              ),
            ),
    );
  }

  // ---------- Image ----------
  Widget _imageHeader(FoodRecord r, ThemeData theme) {
    if (widget.imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(widget.imageBytes!,
            height: 220, width: double.infinity, fit: BoxFit.cover),
      );
    }
    if (r.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(r.imageUrl!,
            height: 220, width: double.infinity, fit: BoxFit.cover),
      );
    }
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.restaurant,
            size: 48, color: theme.colorScheme.outline),
      ),
    );
  }

  // ---------- Name & Category ----------
  Widget _dishNameRow(FoodRecord r, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _editText(
              title: '菜名',
              initial: r.dishName,
              onSubmit: (v) => setState(() => _record = r.copyWith(dishName: v)),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    r.dishName,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined,
                    size: 16, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
        _dropdownChip(
          value: r.category,
          items: _categories,
          onChanged: (v) => setState(() => _record = r.copyWith(category: v)),
        ),
      ],
    );
  }

  Widget _metaChips(FoodRecord r, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        InkWell(
          onTap: () => _editNumber(
            title: '人数',
            initial: r.servingSize.toString(),
            onSubmit: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) {
                setState(() => _record = r.copyWith(servingSize: n));
              }
            },
          ),
          child: _chip(theme, '${r.servingSize}人份', editable: true),
        ),
        _dropdownChip(
          value: r.difficulty,
          items: _difficulties,
          onChanged: (v) => setState(() => _record = r.copyWith(difficulty: v)),
        ),
        InkWell(
          onTap: () => _editNumber(
            title: '总成本(元)',
            initial: (r.totalCost ?? 0).toStringAsFixed(1),
            onSubmit: (v) {
              final n = double.tryParse(v);
              if (n != null) {
                setState(() => _record = r.copyWith(totalCost: n));
              }
            },
          ),
          child: _chip(
            theme,
            '¥${(r.totalCost ?? 0).toStringAsFixed(1)}',
            editable: true,
            highlight: true,
          ),
        ),
      ],
    );
  }

  // ---------- Ingredients ----------
  Widget _ingredientsBlock(FoodRecord r, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, '耗材清单',
            onAdd: () => _editIngredient(null)),
        const SizedBox(height: 8),
        ...r.ingredients.asMap().entries.map((e) {
          final i = e.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text('${i.name} ${_fmtNum(i.amount)}${i.unit}'),
              subtitle: Row(
                children: [
                  Text('¥${i.estimatedPrice.toStringAsFixed(1)}',
                      style: TextStyle(color: theme.colorScheme.primary)),
                  if (i.priceSource == 'user') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '你的价格',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editIngredient(e.key),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: theme.colorScheme.error),
                    onPressed: () => _removeIngredient(e.key),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------- Steps (拖拽) ----------
  Widget _stepsBlock(FoodRecord r, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, '制作步骤', onAdd: () => _editStep(null)),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: r.steps.length,
          onReorder: _reorderStep,
          itemBuilder: (_, idx) {
            final s = r.steps[idx];
            return Card(
              key: ValueKey('step-$idx-${s.description.hashCode}'),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: idx,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text('${idx + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimary)),
                  ),
                ),
                title: Text(s.description),
                subtitle: s.durationMinutes > 0
                    ? Text('约 ${s.durationMinutes} 分钟')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editStep(idx),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: theme.colorScheme.error),
                      onPressed: () => _removeStep(idx),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------- Tips ----------
  Widget _tipsBlock(FoodRecord r, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, '小贴士', onAdd: () => _editTip(null)),
        const SizedBox(height: 8),
        ...r.tips.asMap().entries.map((e) {
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: const Text('💡', style: TextStyle(fontSize: 18)),
              title: Text(e.value),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: theme.colorScheme.error),
                onPressed: () => _removeTip(e.key),
              ),
              onTap: () => _editTip(e.key),
            ),
          );
        }),
      ],
    );
  }

  // ---------- Notes ----------
  Widget _notesField(FoodRecord r) {
    return TextField(
      controller: _notesCtrl,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: '备注（可选）',
        border: OutlineInputBorder(),
        hintText: '比如：妈妈的味道、第一次做、客人很喜欢…',
      ),
      onChanged: (v) =>
          _record = _record!.copyWith(notes: v.isEmpty ? null : v),
    );
  }

  // ---------- Feedback ----------
  Future<void> _showFeedbackSheet(FoodRecord r) async {
    final reasons = <String, String>{
      'wrong_dish': '菜名识别错了',
      'wrong_ingredients': '材料不准',
      'wrong_steps': '步骤不对',
      'wrong_cost': '价格离谱',
      'other': '其他',
    };
    final selected = <String>{};
    final commentCtrl = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('反馈识别问题',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '反馈不会改变这次的结果，但能帮我们改进 AI',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.entries.map((e) {
                    final on = selected.contains(e.key);
                    return FilterChip(
                      label: Text(e.value),
                      selected: on,
                      onSelected: (_) => setSt(() {
                        if (on) {
                          selected.remove(e.key);
                        } else {
                          selected.add(e.key);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '想说点什么？（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            await _submitFeedback(
                              r,
                              reasons: selected.toList(),
                              comment: commentCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                    child: const Text('提交反馈'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('谢谢反馈，我们会持续改进')),
      );
    }
  }

  Future<void> _submitFeedback(
    FoodRecord r, {
    required List<String> reasons,
    required String comment,
  }) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.dio.post('/ai/feedback', data: {
        // 已保存的记录走 food_id；新记录走 image_url
        if (!_isNew) 'food_id': widget.foodId,
        if (_isNew && r.imageUrl != null) 'image_url': r.imageUrl,
        'reasons': reasons,
        if (comment.isNotEmpty) 'comment': comment,
      });
    } catch (_) {
      // 反馈失败不打断主流程
    }
  }

  // ---------- Save ----------
  Future<void> _save() async {
    final r = _record;
    if (r == null) return;
    if (r.dishName.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写菜名')));
      return;
    }
    setState(() => _saving = true);

    final api = ref.read(apiClientProvider);
    try {
      if (_isNew) {
        // 复购检测：后端可能返回 200 + duplicate_of
        final res = await api.dio.post('/foods', data: r.toCreateJson());
        if (res.statusCode == 200 && res.data is Map && res.data['duplicate_of'] != null) {
          final mergeIntoId = res.data['duplicate_of'] as String;
          final candidate = FoodRecord.fromJson(
              res.data['candidate'] as Map<String, dynamic>);
          if (!mounted) return;
          final action = await _showDuplicateDialog(candidate);
          if (action == 'merge') {
            await api.dio.put('/foods/$mergeIntoId', data: r.toCreateJson());
          } else if (action == 'force') {
            await api.dio.post('/foods?force=true', data: r.toCreateJson());
          } else {
            setState(() => _saving = false);
            return;
          }
        }
      } else {
        await api.dio.put('/foods/${widget.foodId}', data: r.toCreateJson());
      }
      ref.read(foodListProvider.notifier).loadFirst();
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<String?> _showDuplicateDialog(FoodRecord candidate) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已有相似记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('你本月已经记录过 "${candidate.dishName}"，要怎么处理？'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'force'),
              child: const Text('新建一条')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: const Text('更新原记录')),
        ],
      ),
    );
  }

  // ---------- Edit helpers ----------
  Future<void> _editText({
    required String title,
    required String initial,
    required ValueChanged<String> onSubmit,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) onSubmit(v);
  }

  Future<void> _editNumber({
    required String title,
    required String initial,
    required ValueChanged<String> onSubmit,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) onSubmit(v);
  }

  Future<void> _editIngredient(int? idx) async {
    final r = _record!;
    final existing = idx == null ? null : r.ingredients[idx];
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '1');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    final priceCtrl = TextEditingController(
        text: existing?.estimatedPrice.toStringAsFixed(1) ?? '0');

    final result = await showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? '添加材料' : '编辑材料',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: '材料名', border: OutlineInputBorder()),
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
                        labelText: '¥价格', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  Navigator.pop(
                    ctx,
                    Ingredient(
                      name: name,
                      amount: double.tryParse(amountCtrl.text) ?? 1,
                      unit: unitCtrl.text.trim(),
                      estimatedPrice: double.tryParse(priceCtrl.text) ?? 0,
                      // 用户改了价格 → 标记为 user，保存时后端会写入个人价格表
                      priceSource: (existing == null ||
                              existing.estimatedPrice !=
                                  (double.tryParse(priceCtrl.text) ?? 0))
                          ? 'user'
                          : existing.priceSource,
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final list = [...r.ingredients];
    if (idx == null) {
      list.add(result);
    } else {
      list[idx] = result;
    }
    setState(() {
      _record = r.copyWith(
        ingredients: list,
        totalCost: list.fold<double>(0, (s, i) => s + i.estimatedPrice),
      );
    });
  }

  void _removeIngredient(int idx) {
    final r = _record!;
    final list = [...r.ingredients]..removeAt(idx);
    setState(() {
      _record = r.copyWith(
        ingredients: list,
        totalCost: list.fold<double>(0, (s, i) => s + i.estimatedPrice),
      );
    });
  }

  Future<void> _editStep(int? idx) async {
    final r = _record!;
    final existing = idx == null ? null : r.steps[idx];
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final minCtrl =
        TextEditingController(text: (existing?.durationMinutes ?? 0).toString());

    final result = await showModalBottomSheet<StepData>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? '添加步骤' : '编辑步骤',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: '步骤描述', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '耗时（分钟，可留空）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final desc = descCtrl.text.trim();
                  if (desc.isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  Navigator.pop(
                    ctx,
                    StepData(
                      stepNum: existing?.stepNum ?? (idx ?? r.steps.length) + 1,
                      description: desc,
                      durationMinutes: int.tryParse(minCtrl.text) ?? 0,
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final list = [...r.steps];
    if (idx == null) {
      list.add(result);
    } else {
      list[idx] = result;
    }
    setState(() => _record = r.copyWith(steps: _renumber(list)));
  }

  void _removeStep(int idx) {
    final r = _record!;
    final list = [...r.steps]..removeAt(idx);
    setState(() => _record = r.copyWith(steps: _renumber(list)));
  }

  void _reorderStep(int oldIdx, int newIdx) {
    final r = _record!;
    final list = [...r.steps];
    if (newIdx > oldIdx) newIdx -= 1;
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);
    setState(() => _record = r.copyWith(steps: _renumber(list)));
  }

  List<StepData> _renumber(List<StepData> list) {
    return [
      for (var i = 0; i < list.length; i++) list[i].copyWith(stepNum: i + 1),
    ];
  }

  Future<void> _editTip(int? idx) async {
    final r = _record!;
    await _editText(
      title: idx == null ? '添加小贴士' : '编辑小贴士',
      initial: idx == null ? '' : r.tips[idx],
      onSubmit: (v) {
        final list = [...r.tips];
        if (idx == null) {
          list.add(v);
        } else {
          list[idx] = v;
        }
        setState(() => _record = r.copyWith(tips: list));
      },
    );
  }

  void _removeTip(int idx) {
    final r = _record!;
    final list = [...r.tips]..removeAt(idx);
    setState(() => _record = r.copyWith(tips: list));
  }

  // ---------- atoms ----------
  Widget _sectionHeader(ThemeData theme, String title,
      {required VoidCallback onAdd}) {
    return Row(
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加'),
        ),
      ],
    );
  }

  Widget _chip(ThemeData theme, String label,
      {bool editable = false, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined,
                size: 12, color: theme.colorScheme.outline),
          ],
        ],
      ),
    );
  }

  Widget _dropdownChip<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
