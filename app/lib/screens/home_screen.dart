import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/food_list_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/food_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  final _categories = ['全部', '家常菜', '烘焙', '饮品', '汤品', '小吃', '面食', '其他'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(foodListProvider.notifier).loadFirst());
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
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
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的美食日记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索菜名...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onSubmitted: (q) => ref.read(foodListProvider.notifier).search(q),
            ),
          ),

          // Category chips
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

          // Food list
          Expanded(
            child: state.items.isEmpty && !state.isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant, size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('还没有美食记录',
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 4),
                        Text('去拍照识别第一道菜吧！',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(foodListProvider.notifier).refresh(),
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: state.items.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.items.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final record = state.items[index];
                        return FoodCard(
                          record: record,
                          onTap: () => context.push('/food/${record.id}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/camera'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('拍照识别'),
      ),
    );
  }
}
