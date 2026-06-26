import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../models/food_record.dart';

class ShareCard extends StatelessWidget {
  final FoodRecord record;

  const ShareCard({super.key, required this.record});

  Future<void> _share(BuildContext context) async {
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    final tmpDir = await Share.shareXFiles(
      [XFile.fromData(bytes, name: '${record.dishName}.png', mimeType: 'image/png')],
      subject: record.dishName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('分享卡片', style: theme.textTheme.titleMedium),
              FilledButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('分享'),
              ),
            ],
          ),
        ),
        RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('🍽️', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(record.dishName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 4),
                      Text('来自 Delicious 的美食记录',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat(context, '人数', '${record.servingSize}人份'),
                          _stat(context, '难度', record.difficulty),
                          _stat(context, '成本',
                              '¥${(record.totalCost ?? 0).toStringAsFixed(1)}'),
                        ],
                      ),
                      const Divider(height: 32),
                      Text('材料清单',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...record.ingredients.take(6).map((i) => Text(
                            '${i.name} ${i.amount}${i.unit}',
                            style: theme.textTheme.bodySmall,
                          )),
                      if (record.ingredients.length > 6)
                        Text('...还有${record.ingredients.length - 6}项',
                            style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      Text('制作步骤',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...record.steps.take(4).map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('${s.stepNum}. ${s.description}',
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
