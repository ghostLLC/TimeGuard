import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../models/app_limit.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/theme.dart';
import '../../providers/app_limits_provider.dart';
import '../../providers/usage_provider.dart';
import '../../providers/achievement_provider.dart';
import 'add_limit_sheet.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(appLimitsProvider);
    final todayUsage = ref.watch(todayUsageProvider);
    final streak = ref.watch(streakProvider);

    // 计算今日总屏幕时间
    final totalMinutes = todayUsage.values.fold(0.0, (s, v) => s + v);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(appLimitsProvider.notifier).load();
          ref.read(todayUsageProvider.notifier).load();
          ref.read(streakProvider.notifier).load();
        },
        child: CustomScrollView(
          slivers: [
            // ── 顶部总览卡片 ──
            SliverToBoxAdapter(
              child: _buildOverviewCard(context, totalMinutes, streak),
            ),

            // ── 限额列表标题 ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '应用限额',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (limits.isNotEmpty)
                      Text(
                        '${limits.length} 个应用',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                  ],
                ),
              ),
            ),

            // ── 限额列表 ──
            if (limits.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(context),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final limit = limits[index];
                    final used = todayUsage[limit.packageName] ?? 0;
                    return _buildLimitCard(context, ref, limit, used);
                  },
                  childCount: limits.length,
                ),
              ),

            // 底部留白
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLimitSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 顶部总览卡片
  Widget _buildOverviewCard(
      BuildContext context, double totalMinutes, int streakDays) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日屏幕时间',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppUtils.formatMinutes(totalMinutes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              if (streakDays > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '连续 $streakDays 天',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 单个限额卡片
  Widget _buildLimitCard(
      BuildContext context, WidgetRef ref, AppLimit limit, double usedMinutes) {
    final progress = limit.dailyLimitMinutes > 0
        ? (usedMinutes / limit.dailyLimitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final isOvertime = usedMinutes >= limit.dailyLimitMinutes;
    final remaining = (limit.dailyLimitMinutes - usedMinutes).clamp(0, double.infinity);
    final progressColor = Color(AppUtils.progressColor(
        usedMinutes, limit.dailyLimitMinutes.toDouble()));

    return Dismissible(
      key: ValueKey('limit_${limit.id ?? limit.packageName}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) {
        if (limit.id != null) {
          ref.read(appLimitsProvider.notifier).removeLimit(limit.id!);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOvertime
              ? Colors.red.shade50
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: isOvertime
              ? Border.all(color: Colors.red.shade200)
              : null,
        ),
        child: Row(
          children: [
            // 圆形进度
            CircularPercentIndicator(
              radius: 24,
              lineWidth: 5,
              percent: progress,
              center: Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
              progressColor: progressColor,
              backgroundColor: progressColor.withOpacity(0.15),
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
            ),
            const SizedBox(width: 14),

            // 应用信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    limit.appName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isOvertime ? Colors.red : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已用 ${AppUtils.formatMinutes(usedMinutes)}'
                    ' / 限额 ${AppUtils.formatMinutes(limit.dailyLimitMinutes.toDouble())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  // 时段限额标签
                  if (limit.hasPeriodLimits) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (limit.morningLimitMinutes != null)
                          _buildPeriodChip('上午', limit.morningLimitMinutes!, usedMinutes, TimePeriod.morning),
                        if (limit.afternoonLimitMinutes != null)
                          _buildPeriodChip('下午', limit.afternoonLimitMinutes!, usedMinutes, TimePeriod.afternoon),
                        if (limit.eveningLimitMinutes != null)
                          _buildPeriodChip('晚上', limit.eveningLimitMinutes!, usedMinutes, TimePeriod.evening),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 剩余时间或超时标记
            if (isOvertime)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '超时',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                '剩 ${AppUtils.formatMinutes(remaining.toDouble())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 时段限额标签
  Widget _buildPeriodChip(String label, int limitMin, double usedMin, TimePeriod period) {
    final currentPeriod = TimePeriodExtension.fromHour(DateTime.now().hour);
    final isActive = period == currentPeriod;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label ${AppUtils.formatMinutes(limitMin.toDouble())}',
        style: TextStyle(
          fontSize: 10,
          color: isActive ? AppTheme.primaryColor : Colors.grey,
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 40, 16, 0),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有设置限额',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 按钮\n为应用设定每日使用时间',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLimitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddLimitSheet(),
    );
  }
}
