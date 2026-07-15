import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/xiaomi_helper.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final points = ref.watch(pointsProvider);
    final streak = ref.watch(streakProvider);
    final unlockedCount =
        achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 数据总览 ──
            Row(
              children: [
                _buildStatCard(context, '$points', '积分', Icons.stars,
                    Colors.amber),
                const SizedBox(width: 12),
                _buildStatCard(context, '$streak', '连续天数',
                    Icons.local_fire_department, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard(context, '$unlockedCount/${achievements.length}',
                    '成就', Icons.workspace_premium, AppTheme.primaryColor),
              ],
            ),

            const SizedBox(height: 24),

            // ── 成就墙 ──
            Text(
              '成就徽章',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                return _buildBadgeTile(context, achievement);
              },
            ),

            const SizedBox(height: 24),

            // ── 设置项 ──
            Text(
              '设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phonelink_setup),
                    title: const Text('设备适配引导'),
                    subtitle: const Text('自启动/省电策略设置'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showXiaomiGuide(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('通知设置'),
                    subtitle: const Text('管理通知权限'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await XiaomiHelper.requestNotificationPermission();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('关于 TimeGuard'),
                    subtitle: Text('版本 ${AppConstants.appVersion}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: AppConstants.appVersion,
                        applicationLegalese:
                            '一款帮助你管理屏幕时间的自律工具',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeTile(BuildContext context, achievement) {
    final isUnlocked = achievement.isUnlocked as bool;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isUnlocked
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: isUnlocked
                  ? AppTheme.primaryColor
                  : Colors.grey.shade200,
              width: 2,
            ),
          ),
          child: Icon(
            _getIconData(achievement.iconName as String),
            size: 24,
            color: isUnlocked ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          achievement.name as String,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
            color: isUnlocked ? null : Colors.grey.shade400,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  IconData _getIconData(String name) {
    const iconMap = {
      'eco': Icons.eco,
      'local_florist': Icons.local_florist,
      'shield': Icons.shield,
      'star': Icons.star,
      'workspace_premium': Icons.workspace_premium,
      'self_improvement': Icons.self_improvement,
      'chat_bubble_outline': Icons.chat_bubble_outline,
      'signpost': Icons.signpost,
    };
    return iconMap[name] ?? Icons.star;
  }

  void _showXiaomiGuide(BuildContext context) async {
    final steps = await XiaomiHelper.getGuideSteps();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设备适配引导',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...steps.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: step.isRequired
                                ? AppTheme.primaryColor
                                : Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            step.isRequired
                                ? Icons.check
                                : Icons.info_outline,
                            size: 16,
                            color: step.isRequired
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                step.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                onPressed: () => _handleGuideAction(step.action),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('去设置'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _handleGuideAction(String action) {
    switch (action) {
      case 'usage_stats':
        XiaomiHelper.requestUsageStatsPermission();
        break;
      case 'notification':
        XiaomiHelper.requestNotificationPermission();
        break;
      case 'auto_start':
        XiaomiHelper.openAutoStartSettings();
        break;
      case 'battery_optimization':
        XiaomiHelper.openBatteryOptimizationSettings();
        break;
      case 'lock_recent':
        // 无法自动操作，提示用户手动
        break;
    }
  }
}
