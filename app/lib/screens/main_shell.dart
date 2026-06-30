import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _tabButton(
                context,
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: '日记',
                selected: navigationShell.currentIndex == 0,
                onTap: () => navigationShell.goBranch(0, initialLocation: true),
              ),
              _cameraButton(context, theme),
              _tabButton(
                context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: '我的',
                selected: navigationShell.currentIndex == 1,
                onTap: () => navigationShell.goBranch(1, initialLocation: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _cameraButton(BuildContext context, ThemeData theme) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: () => context.push('/camera'),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.camera_alt,
              color: theme.colorScheme.onPrimary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
