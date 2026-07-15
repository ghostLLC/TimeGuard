import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'providers/settings_provider.dart';
import 'pages/home/home_page.dart';
import 'pages/stats/stats_page.dart';
import 'pages/focus/focus_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/onboarding/onboarding_page.dart';

class TimeGuardApp extends ConsumerWidget {
  const TimeGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: '时用 TimeGuard',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: _buildRouter(settings.onboardingDone, ref),
    );
  }

  GoRouter _buildRouter(bool onboardingDone, WidgetRef ref) {
    return GoRouter(
      initialLocation: onboardingDone ? '/home' : '/onboarding',
      routes: [
        // 引导页
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => OnboardingPage(
            onComplete: () {
              context.go('/home');
            },
          ),
        ),

        // 主页（带底部导航）
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomePage(),
              ),
            ),
            GoRoute(
              path: '/stats',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: StatsPage(),
              ),
            ),
            GoRoute(
              path: '/focus',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: FocusPage(),
              ),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProfilePage(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 主界面壳 — 底部 TabBar
class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _routes = ['/home', '/stats', '/focus', '/profile'];

  @override
  Widget build(BuildContext context) {
    // 根据当前路由更新选中索引
    final location = GoRouterState.of(context).uri.path;
    final index = _routes.indexOf(location);
    if (index >= 0 && index != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = index);
      });
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex >= 0 ? _currentIndex : 0,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          context.go(_routes[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement),
            label: '专注',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
