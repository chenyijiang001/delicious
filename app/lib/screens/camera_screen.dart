import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/camera_provider.dart';
import '../providers/food_detail_provider.dart';

class CameraScreen extends ConsumerWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraProvider);
    final notifier = ref.read(cameraProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照识别'),
        actions: [
          if (state.status == CameraStatus.done)
            TextButton(
              onPressed: () async {
                if (state.recipe != null) {
                  final record = recipeToRecord(state.recipe!);
                  notifier.reset();
                  context.push('/food/new/edit', extra: record);
                }
              },
              child: const Text('确认并保存'),
            ),
        ],
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(BuildContext context, CameraState state, CameraNotifier notifier) {
    switch (state.status) {
      case CameraStatus.idle:
      case CameraStatus.picking:
        return _buildImagePreview(context, state, notifier);
      case CameraStatus.uploading:
      case CameraStatus.analyzing:
        return _buildAnalyzing(context);
      case CameraStatus.done:
        return _buildResult(context, state);
      case CameraStatus.error:
        return _buildError(context, state, notifier);
    }
  }

  Widget _buildImagePreview(
      BuildContext context, CameraState state, CameraNotifier notifier) {
    final hasImage = state.imageBytes != null;

    return Column(
      children: [
        Expanded(
          child: hasImage
              ? Image.memory(state.imageBytes!, fit: BoxFit.contain)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 80,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('拍照或选择一张美食图片',
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(notifier, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('相册'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _pickImage(notifier, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('拍照'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton(
              onPressed: () => notifier.analyze(),
              child: const Text('开始识别'),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage(CameraNotifier notifier, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 100);
    if (picked != null) {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      notifier.setImage(file, bytes);
    }
  }

  Widget _buildAnalyzing(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text('AI 正在识别中...',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('分析食材、估算成本、生成步骤',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, CameraState state) {
    final recipe = state.recipe!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: state.imageBytes != null
                ? Image.memory(state.imageBytes!, fit: BoxFit.cover,
                    width: double.infinity, height: 220)
                : null,
          ),
          const SizedBox(height: 16),

          // Name & category
          Row(
            children: [
              Expanded(
                child: Text(recipe.dishName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ),
              Chip(label: Text(recipe.category)),
            ],
          ),
          const SizedBox(height: 8),

          // Cost & difficulty
          Row(
            children: [
              _infoChip(context, '${recipe.servingSize}人份'),
              const SizedBox(width: 8),
              _infoChip(context, recipe.difficulty),
              const SizedBox(width: 8),
              _infoChip(context, '¥${recipe.totalCost.toStringAsFixed(1)}'),
            ],
          ),
          const SizedBox(height: 20),

          // Ingredients
          Text('耗材清单', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          ...recipe.ingredients.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('${i.name} ${i.amount}${i.unit}')),
                    Text('¥${i.estimatedPrice.toStringAsFixed(1)}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              )),
          const SizedBox(height: 20),

          // Steps
          Text('制作步骤', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          ...recipe.steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text('${s.stepNum}',
                          style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.description)),
                    if (s.durationMinutes > 0)
                      Text('${s.durationMinutes}分',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              )),
          const SizedBox(height: 20),

          // Tips
          if (recipe.tips.isNotEmpty) ...[
            Text('小贴士', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 8),
            ...recipe.tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 '),
                      Expanded(child: Text(t)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildError(
      BuildContext context, CameraState state, CameraNotifier notifier) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(state.errorMessage ?? '未知错误'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => notifier.reset(), child: const Text('重试')),
        ],
      ),
    );
  }
}
