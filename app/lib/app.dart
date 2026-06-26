import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/food_detail_screen.dart';
import 'screens/edit_food_screen.dart';
import 'screens/auth_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final goingToAuth = state.matchedLocation == '/auth';
      if (!loggedIn && !goingToAuth) return '/auth';
      if (loggedIn && goingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/camera',
        builder: (_, __) => const CameraScreen(),
      ),
      GoRoute(
        path: '/food/:id',
        builder: (_, state) => FoodDetailScreen(
          foodId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/food/:id/edit',
        builder: (_, state) => EditFoodScreen(
          foodId: state.pathParameters['id']!,
        ),
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
