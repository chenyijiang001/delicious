import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/cost_panel_screen.dart';
import 'screens/food_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/prices_screen.dart';
import 'screens/buy_suggestion_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipe_editor_screen.dart';
import 'screens/shopping_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;
      final atAuth = loc == '/auth';
      final atOnboarding = loc == '/onboarding';

      // 未登录：除了 /auth 都拦回
      if (!loggedIn) return atAuth ? null : '/auth';

      // 已登录且需要引导：除了 /onboarding 和 /camera 都拦到 /onboarding
      // (/camera 放行是为了让"立即拍第一张"按钮能走通)
      if (auth.needsOnboarding && !atOnboarding && loc != '/camera') {
        return '/onboarding';
      }

      // 已登录但还在 /auth 页：跳走
      if (atAuth) return auth.needsOnboarding ? '/onboarding' : '/home';

      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),

      // 全屏二级页（不显示底部 Tab）
      GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),

      // /food/:id/edit 比 /food/:id 更具体，按 GoRouter 文档放在前面更稳
      GoRoute(
        path: '/food/:id/edit',
        builder: (_, state) {
          final extra = state.extra;
          return RecipeEditorScreen(
            foodId: state.pathParameters['id']!,
            initialRecord: extra is Map ? extra['record'] : null,
            imageBytes: extra is Map ? extra['imageBytes'] : null,
          );
        },
      ),
      GoRoute(
        path: '/food/:id',
        builder: (_, state) =>
            FoodDetailScreen(foodId: state.pathParameters['id']!),
      ),

      GoRoute(path: '/shopping', builder: (_, __) => const ShoppingScreen()),
      GoRoute(
        path: '/shopping/buy',
        builder: (_, __) => const BuySuggestionScreen(),
      ),
      GoRoute(path: '/prices', builder: (_, __) => const PricesScreen()),
      GoRoute(path: '/cost', builder: (_, __) => const CostPanelScreen()),

      // 底部 Tab：日记 / 我的（中间的拍照是浮动按钮，不算 branch）
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/profile', builder: (_, __) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

class DeliciousApp extends ConsumerWidget {
  const DeliciousApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Delicious',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65C41),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      routerConfig: router,
    );
  }
}
