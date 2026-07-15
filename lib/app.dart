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

/// 稳定的 GoRouter 实例（不在 build 中重建）
final _rootNavigatorKey = GlobalKey<NavigatorState>();

class TimeGuardApp extends ConsumerStatefulWidget {
  const TimeGuardApp({super.key});

  @override
  ConsumerState<TimeGuardApp> createState() => _TimeGuardAppState();
}

class _TimeGuardAppState extends ConsumerState<TimeGuardApp> {
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/home',
      redirect: _redirect,
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('页面不存在', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => OnboardingPage(
            onComplete: () => context.go('/home'),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, __) => const NoTransitionPage(child: HomePage()),
            ),
            GoRoute(
              path: '/stats',
              pageBuilder: (_, __) => const NoTransitionPage(child: StatsPage()),
            ),
            GoRoute(
              path: '/focus',
              pageBuilder: (_, __) => const NoTransitionPage(child: FocusPage()),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (_, __) => const NoTransitionPage(child: ProfilePage()),
            ),
          ],
        ),
      ],
    );
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final onboardingDone = ref.read(settingsProvider).onboardingDone;
    final isOnboarding = state.uri.path == '/onboarding';

    // 已完成引导 → 不允许回到引导页
    if (isOnboarding && onboardingDone) return '/home';
    // 未完成引导 → 强制进入引导页
    if (!isOnboarding && !onboardingDone) return '/onboarding';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 监听 settings 变化以触发 redirect 重评估
    ref.listen(settingsProvider, (_, __) {
      _router.refresh();
    });

    return MaterialApp.router(
      title: '时用 TimeGuard',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
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
  static const _routes = ['/home', '/stats', '/focus', '/profile'];

  int get _currentIndex {
    final path = GoRouterState.of(context).uri.path;
    final idx = _routes.indexOf(path);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0, // 只在首页允许退出
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          context.go('/home'); // 其他 Tab 按返回键回到首页
        }
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
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
      ),
    );
  }
}
