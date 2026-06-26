import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_record.dart';

class FoodCard extends StatelessWidget {
  final FoodRecord record;
  final VoidCallback? onTap;

  const FoodCard({super.key, required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('MM-dd HH:mm').format(record.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 100,
              height: 100,
              child: record.thumbnailUrl != null
                  ? Image.network(
                      record.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.dishName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _tag(theme, record.category),
                        const SizedBox(width: 6),
                        _tag(theme, record.difficulty),
                        if (record.totalCost != null) ...[
                          const SizedBox(width: 6),
                          _tag(theme, '¥${record.totalCost!.toStringAsFixed(1)}'),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Text(timeStr,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.restaurant,
          color: Theme.of(context).colorScheme.outline),
    );
  }

  Widget _tag(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
