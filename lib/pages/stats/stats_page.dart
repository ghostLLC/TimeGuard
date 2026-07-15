import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/utils.dart';
import '../../core/theme.dart';
import '../../providers/usage_provider.dart';
import '../../providers/app_limits_provider.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage>
    with SingleTickerProviderStateMixin {
  int _selectedRange = 0; // 0=today, 1=week, 2=month
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedRange = _tabController.index);
        _loadData();
      }
    });
    _loadData();
  }

  void _loadData() {
    final days = [1, 7, 30][_selectedRange];
    ref.read(usageHistoryProvider.notifier).loadDailyTotals(days);
    ref.read(usageHistoryProvider.notifier).loadRange(days);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayUsage = ref.watch(todayUsageProvider);
    final history = ref.watch(usageHistoryProvider);
    final limits = ref.watch(appLimitsProvider);

    // 根据选中周期选择数据源
    final displayUsage = _selectedRange == 0
        ? todayUsage
        : (history['total'] ?? <String, double>{});

    return Scaffold(
      appBar: AppBar(
        title: const Text('使用统计'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '今日'),
            Tab(text: '本周'),
            Tab(text: '本月'),
          ],
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 总览
            _buildTotalCard(context, displayUsage),

            const SizedBox(height: 24),

            // 使用时长分布（环形图）
            _buildPieChart(context, displayUsage),

            const SizedBox(height: 24),

            // 趋势折线图
            if (_selectedRange > 0)
              _buildTrendChart(context, history['daily'] ?? {}),

            if (_selectedRange > 0)
              const SizedBox(height: 24),

            // 各应用限额对比柱状图
            _buildBarChart(context, displayUsage, limits),

            const SizedBox(height: 24),

            // 排行榜
            _buildRanking(context, displayUsage),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// 总时长卡片
  Widget _buildTotalCard(BuildContext context, Map<String, double> usage) {
    final total = usage.values.fold(0.0, (s, v) => s + v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ['今日', '本周', '本月'][_selectedRange],
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppUtils.formatMinutesChinese(total),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '共 ${usage.length} 个应用有使用记录',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  /// 环形图 - 使用时长分布
  Widget _buildPieChart(BuildContext context, Map<String, double> usage) {
    if (usage.isEmpty) {
      return _buildEmptyChart(context, '暂无使用数据');
    }

    // 取 Top 5 + 其他
    final sorted = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final otherSum = sorted.skip(5).fold(0.0, (s, e) => s + e.value);

    final colors = [
      AppTheme.primaryColor,
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF6B7280),
      const Color(0xFFD1D5DB),
    ];

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < top5.length; i++) {
      sections.add(PieChartSectionData(
        value: top5[i].value,
        color: colors[i],
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ));
    }
    if (otherSum > 0) {
      sections.add(PieChartSectionData(
        value: otherSum,
        color: colors[5],
        radius: 50,
        title: '其他',
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '使用分布',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 图例
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (int i = 0; i < top5.length; i++)
                  _buildLegend(
                      colors[i], _getAppName(top5[i].key), top5[i].value),
                if (otherSum > 0)
                  _buildLegend(colors[5], '其他', otherSum),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 趋势折线图
  Widget _buildTrendChart(BuildContext context, Map<String, double> daily) {
    if (daily.isEmpty) {
      return _buildEmptyChart(context, '暂无趋势数据');
    }

    final spots = daily.entries.toList().asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每日屏幕时间趋势',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 柱状图 - 各应用限额对比
  Widget _buildBarChart(BuildContext context, Map<String, double> usage,
      List limits) {
    if (limits.isEmpty) {
      return _buildEmptyChart(context, '暂无限额数据');
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < limits.length && i < 8; i++) {
      final limit = limits[i];
      final used = usage[limit.packageName] ?? 0;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: limit.dailyLimitMinutes.toDouble(),
            color: Colors.grey.shade200,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: used,
            color: used >= limit.dailyLimitMinutes
                ? Colors.red
                : AppTheme.primaryColor,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '限额 vs 已用',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 排行榜
  Widget _buildRanking(BuildContext context, Map<String, double> usage) {
    if (usage.isEmpty) return const SizedBox.shrink();

    final sorted = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10 = sorted.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '使用排行',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            ...top10.asMap().entries.map((e) {
              final rank = e.key + 1;
              final entry = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? [Colors.amber, Colors.grey.shade400,
                                const Color(0xFFCD7F32)][rank - 1]
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade700
                                : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rank <= 3 ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getAppName(entry.key),
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppUtils.formatMinutes(entry.value),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label, double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${AppUtils.formatMinutes(value)}',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  String _getAppName(String packageName) {
    final limits = ref.read(appLimitsProvider);
    for (final l in limits) {
      if (l.packageName == packageName) return l.appName;
    }
    // 截取包名最后一段作为显示名
    final parts = packageName.split('.');
    return parts.last;
  }
}
