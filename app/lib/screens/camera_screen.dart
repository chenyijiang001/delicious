import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_record.dart';
import '../providers/camera_provider.dart';
import '../providers/food_detail_provider.dart';
import '../services/analytics_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  Timer? _stageTimer;
  int _stage = 0;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(analyticsProvider).log('camera_open', {'source': 'tab'});
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  void _startStageTicker() {
    _stageTimer?.cancel();
    _stage = 0;
    _stageTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final started = ref.read(cameraProvider).analyzingStartedAt;
      if (started == null) return;
      final elapsed = DateTime.now().difference(started).inSeconds;
      final next = elapsed < 2 ? 0 : (elapsed < 5 ? 1 : 2);
      if (next != _stage && mounted) {
        setState(() => _stage = next);
      }
    });
  }

  void _stopStageTicker() {
    _stageTimer?.cancel();
    _stageTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CameraState>(cameraProvider, (prev, next) {
      if (next.status == CameraStatus.uploading ||
          next.status == CameraStatus.analyzing) {
        if (_stageTimer == null) _startStageTicker();
      } else {
        _stopStageTicker();
      }

      if (next.status == CameraStatus.done &&
          next.recipe != null &&
          !_navigating) {
        _navigating = true;
        ref.read(analyticsProvider).log('recognize_done', {
          'cache_hit': next.recipe!.cacheHit,
          'latency_ms': next.recipe!.latencyMs,
        });
        final record = recipeToRecord(next.recipe!);
        final bytes = next.imageBytes;
        ref.read(cameraProvider.notifier).reset();
        Future.microtask(() {
          if (mounted) {
            context.pushReplacement('/food/new/edit', extra: {
              'record': record,
              'imageBytes': bytes,
            });
          }
        });
      }

      if (next.status == CameraStatus.error) {
        ref.read(analyticsProvider).log('recognize_fail', {
          'error_code': next.errorCode ?? 'unknown',
        });
      }
    });

    final state = ref.watch(cameraProvider);
    final notifier = ref.read(cameraProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: SafeArea(child: _buildBody(state, notifier)),
    );
  }

  Widget _buildBody(CameraState state, CameraNotifier notifier) {
    switch (state.status) {
      case CameraStatus.idle:
      case CameraStatus.picking:
        return _pickerView(notifier);
      case CameraStatus.uploading:
      case CameraStatus.analyzing:
        return _analyzingView(state);
      case CameraStatus.done:
        // 在 listen 里跳转过去，这里短暂留白
        return const Center(child: CircularProgressIndicator());
      case CameraStatus.error:
        return _errorView(state, notifier);
    }
  }

  // ---------- 选图 ----------
  Widget _pickerView(CameraNotifier notifier) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      size: 80, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('拍一张你的菜', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '选完图自动识别，不用再点确认',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAndAnalyze(notifier, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('从相册'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickAndAnalyze(notifier, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('拍照'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _goManual(),
            child: const Text('或者，手动填写一道菜'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAnalyze(
      CameraNotifier notifier, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) return;
    ref.read(analyticsProvider).log('image_picked', {
      'source': source == ImageSource.camera ? 'camera' : 'gallery',
    });
    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    await notifier.setImageAndAnalyze(file, bytes);
  }

  // ---------- 识别中 ----------
  Widget _analyzingView(CameraState state) {
    final theme = Theme.of(context);
    const stages = [
      (icon: '🍅', text: '识别食物中...'),
      (icon: '💰', text: '估算成本中...'),
      (icon: '📝', text: '生成制作步骤中...'),
    ];
    final stage = stages[_stage.clamp(0, 2)];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (state.imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                state.imageBytes!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              stage.icon,
              key: ValueKey(stage.icon),
              style: const TextStyle(fontSize: 56),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              stage.text,
              key: ValueKey(stage.text),
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(minHeight: 3),
          ),
          const SizedBox(height: 12),
          Text(
            '通常需要 5–8 秒',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ---------- 错误 ----------
  Widget _errorView(CameraState state, CameraNotifier notifier) {
    final theme = Theme.of(context);
    final isNoFood = state.errorCode == 'no_food_detected';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (state.imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                state.imageBytes!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 24),
          Icon(
            isNoFood ? Icons.restaurant_menu_outlined : Icons.error_outline,
            size: 56,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            isNoFood ? '图片里没有看到食物' : '识别失败',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            state.errorMessage ?? '',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                notifier.reset();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('换一张图'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                notifier.reset();
                _goManual();
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('我自己填'),
            ),
          ),
          const SizedBox(height: 8),
          if (!isNoFood)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showFeedbackSheet(state),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('反馈：识别有问题'),
              ),
            ),
        ],
      ),
    );
  }

  void _goManual() {
    final now = DateTime.now();
    final blank = FoodRecord(
      id: 'new',
      dishName: '',
      category: '其他',
      ingredients: const [],
      steps: const [],
      totalCost: 0,
      servingSize: 1,
      difficulty: '中等',
      tips: const [],
      cookedAt: DateTime(now.year, now.month, now.day),
      source: 'manual',
      createdAt: now,
      updatedAt: now,
    );
    context.pushReplacement('/food/new/edit', extra: {'record': blank});
  }

  Future<void> _showFeedbackSheet(CameraState state) async {
    final reasons = <String, String>{
      'wrong_dish': '菜名识别错了',
      'wrong_ingredients': '材料不准',
      'wrong_steps': '步骤不对',
      'wrong_cost': '价格离谱',
      'other': '其他',
    };
    final selected = <String>{};
    final commentCtrl = TextEditingController();

    await showModalBottomSheet(
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
                Text('反馈问题',
                    style: Theme.of(ctx).textTheme.titleMedium),
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
                    onPressed: () {
                      // 无 image_url 时通过埋点上报，不调用 /ai/feedback
                      ref.read(analyticsProvider).log('ai_feedback', {
                        'reasons': selected.toList(),
                        'comment': commentCtrl.text.trim(),
                        'error_code': state.errorCode ?? '',
                      });
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('谢谢反馈，我们会持续改进')),
                        );
                      }
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
  }
}

