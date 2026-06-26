import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/food_record.dart';
import '../models/recipe.dart';
import '../providers/food_detail_provider.dart';
import '../providers/food_list_provider.dart';

class EditFoodScreen extends ConsumerStatefulWidget {
  final String foodId;
  const EditFoodScreen({super.key, required this.foodId});

  @override
  ConsumerState<EditFoodScreen> createState() => _EditFoodScreenState();
}

class _EditFoodScreenState extends ConsumerState<EditFoodScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _servingCtrl;
  late TextEditingController _notesCtrl;
  String _category = '其他';
  String _difficulty = '中等';
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _steps = [];
  List<String> _tips = [];
  String? _imageUrl;
  String? _thumbnailUrl;
  final _formKey = GlobalKey<FormState>();

  final _categories = ['家常菜', '烘焙', '饮品', '汤品', '小吃', '面食', '其他'];
  final _difficulties = ['简单', '中等', '困难'];

  bool get _isNew => widget.foodId == 'new';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _costCtrl = TextEditingController();
    _servingCtrl = TextEditingController(text: '1');
    _notesCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  void _initData() {
    if (_isNew) {
      // Get record from GoRouter extra
      final router = GoRouter.of(context);
      final extra = router.routerDelegate.currentConfiguration.matches.last.extra;

      if (extra is FoodRecord) {
        _populateFromRecord(extra);
      } else {
        // Fallback: empty form
      }
    } else {
      final state = ref.read(foodDetailProvider(widget.foodId));
      if (state.record != null) {
        _populateFromRecord(state.record!);
      }
    }
  }

  void _populateFromRecord(FoodRecord r) {
    setState(() {
      _nameCtrl.text = r.dishName;
      _costCtrl.text = r.totalCost?.toStringAsFixed(1) ?? '';
      _servingCtrl.text = r.servingSize.toString();
      _notesCtrl.text = r.notes ?? '';
      _category = r.category;
      _difficulty = r.difficulty;
      _ingredients = r.ingredients.map((i) => i.toJson()).toList().cast<Map<String, dynamic>>();
      _steps = r.steps.map((s) => s.toJson()).toList().cast<Map<String, dynamic>>();
      _tips = List.from(r.tips);
      _imageUrl = r.imageUrl;
      _thumbnailUrl = r.thumbnailUrl;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _servingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final body = <String, dynamic>{
      'image_url': _imageUrl,
      'thumbnail_url': _thumbnailUrl,
      'dish_name': _nameCtrl.text.trim(),
      'category': _category,
      'ingredients': _ingredients,
      'steps': _steps,
      'total_cost': double.tryParse(_costCtrl.text) ?? 0,
      'serving_size': int.tryParse(_servingCtrl.text) ?? 1,
      'difficulty': _difficulty,
      'tips': _tips,
      'notes': _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
    };

    final api = ref.read(apiClientProvider);
    try {
      if (_isNew) {
        await api.dio.post('/foods', data: body);
      } else {
        await api.dio.put('/foods/${widget.foodId}', data: body);
      }
      ref.read(foodListProvider.notifier).loadFirst();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '保存美食记录' : '编辑美食记录'),
        actions: [
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '菜名',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? '请输入菜名' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    decoration: const InputDecoration(
                      labelText: '总成本(元)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _servingCtrl,
                    decoration: const InputDecoration(
                      labelText: '几人份',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: const InputDecoration(
                labelText: '难度',
                border: OutlineInputBorder(),
              ),
              items: _difficulties
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _difficulty = v!),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),
            Text('材料清单', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._ingredients.asMap().entries.map((entry) {
              final i = entry.value;
              return Card(
                child: ListTile(
                  title: Text('${i['name']} ${i['amount']}${i['unit']}'),
                  trailing: Text('¥${i['estimated_price']}'),
                ),
              );
            }),
            const SizedBox(height: 24),
            Text('制作步骤', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...List.generate(_steps.length, (idx) {
              final s = _steps[idx];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${s['step_num']}')),
                  title: Text(s['description']),
                  trailing: s['duration_minutes'] > 0
                      ? Text('${s['duration_minutes']}分')
                      : null,
                ),
              );
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
