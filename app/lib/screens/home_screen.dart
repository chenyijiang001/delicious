import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/food_list_provider.dart';
import '../widgets/food_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _searchMode = 'dish'; // dish | ingredient

  final _categories = ['全部', '家常菜', '烘焙', '饮品', '汤品', '小吃', '面食', '其他'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(foodListProvider.notifier).loadFirst());
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(foodListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('我的美食日记')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText:
                          _searchMode == 'dish' ? '搜索菜名...' : '搜索食材（如番茄）',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                    ),
                    onSubmitted: (q) {
                      ref
                          .read(foodListProvider.notifier)
                          .search(q, mode: _searchMode);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    _searchMode == 'dish' ? Icons.restaurant : Icons.eco,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: '切换搜索模式',
                  onSelected: (v) {
                    setState(() => _searchMode = v);
                    final q = _searchCtrl.text.trim();
                    if (q.isNotEmpty) {
                      ref
                          .read(foodListProvider.notifier)
                          .search(q, mode: _searchMode);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'dish', child: Text('按菜名搜')),
                    PopupMenuItem(value: 'ingredient', child: Text('按食材搜')),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = cat == '全部'
                    ? state.categoryFilter == null
                    : state.categoryFilter == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) {
                    final filter = cat == '全部' ? null : cat;
                    ref.read(foodListProvider.notifier).filterCategory(filter);
                  },
                );
              },
            ),
          ),

          Expanded(
            child: state.items.isEmpty && !state.isLoading
                ? _empty(theme, context)
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(foodListProvider.notifier).refresh(),
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount:
                          state.items.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.items.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return FoodCard(
                          record: state.items[index],
                          onTap: () =>
                              context.push('/food/${state.items[index].id}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty(ThemeData theme, BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('还没有美食记录', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('点中间相机按钮，拍下第一道菜',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/camera'),
            icon: const Icon(Icons.camera_alt),
            label: const Text('开始拍照'),
          ),
        ],
      ),
    );
  }
}
