import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/xiaomi_helper.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hasUsagePermission = false;
  bool _hasNotificationPermission = false;
  bool _loading = false;

  final _pages = [
    _OnboardingData(
      icon: Icons.timer_outlined,
      title: '掌控你的屏幕时间',
      subtitle: '为每个应用设定每日使用上限\n超时即提醒，帮你养成自律习惯',
    ),
    _OnboardingData(
      icon: Icons.pie_chart_outline,
      title: '可视化使用数据',
      subtitle: '环形图、折线图、排行榜\n一目了然你的使用习惯',
    ),
    _OnboardingData(
      icon: Icons.self_improvement,
      title: '专注模式',
      subtitle: '一键开启专注倒计时\n屏蔽干扰，深度投入',
    ),
    _OnboardingData(
      icon: Icons.workspace_premium,
      title: '成就激励',
      subtitle: '打卡集徽章、攒积分\n让自律变成一件有成就感的事',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    setState(() => _loading = true);
    _hasUsagePermission = await XiaomiHelper.hasUsageStatsPermission();
    _hasNotificationPermission = await XiaomiHelper.hasNotificationPermission();
    setState(() => _loading = false);
  }

  Future<void> _requestUsagePermission() async {
    await XiaomiHelper.requestUsageStatsPermission();
    await _checkPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    await XiaomiHelper.requestNotificationPermission();
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text('跳过'),
                ),
              ),
            ),

            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length + 1, // +1 for permission page
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  if (index < _pages.length) {
                    return _buildIntroPage(_pages[index]);
                  } else {
                    return _buildPermissionPage();
                  }
                },
              ),
            ),

            // 底部导航
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 指示器
                  Row(
                    children: List.generate(
                      _pages.length + 1,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == index ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // 下一步/完成按钮
                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_currentPage < _pages.length) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _completeOnboarding();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < _pages.length ? '下一步' : '开始使用',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroPage(_OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 80, color: AppTheme.primaryColor),
          const SizedBox(height: 32),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: AppTheme.primaryColor),
          const SizedBox(height: 32),
          const Text(
            '需要以下权限',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'TimeGuard 需要这些权限才能正常工作',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // 使用统计权限
          _buildPermissionItem(
            icon: Icons.bar_chart,
            title: '查看应用使用情况',
            description: '读取各应用的使用时间',
            isGranted: _hasUsagePermission,
            onTap: _hasUsagePermission ? null : _requestUsagePermission,
          ),
          const SizedBox(height: 16),

          // 通知权限
          _buildPermissionItem(
            icon: Icons.notifications,
            title: '发送通知',
            description: '超时提醒和专注模式通知',
            isGranted: _hasNotificationPermission,
            onTap:
                _hasNotificationPermission ? null : _requestNotificationPermission,
          ),

          const SizedBox(height: 24),

          // 刷新权限状态
          TextButton(
            onPressed: _checkPermissions,
            child: const Text('刷新权限状态'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted
            ? AppTheme.secondaryColor.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? AppTheme.secondaryColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isGranted ? AppTheme.secondaryColor : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (isGranted)
            const Icon(Icons.check_circle, color: AppTheme.secondaryColor)
          else
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('授权'),
            ),
        ],
      ),
    );
  }

  void _completeOnboarding() async {
    await ref
        .read(settingsProvider.notifier)
        .setOnboardingDone(true);
    widget.onComplete();
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;

  _OnboardingData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
