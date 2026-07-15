import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_usage.dart';
import '../database/database_helper.dart';
import '../core/utils.dart';

/// 今日使用时长状态
class TodayUsageNotifier extends StateNotifier<Map<String, double>> {
  TodayUsageNotifier() : super({}) {
    _init();
  }

  Future<void> _init() async {
    try { await load(); } catch (_) {}
  }

  Future<void> load() async {
    final today = AppUtils.todayString();
    final usages = await DatabaseHelper.getDailyUsage(today);
    state = {for (final u in usages) u.packageName: u.usageMinutes};
  }

  void updateUsage(String packageName, double minutes) {
    state = {...state, packageName: minutes};
  }

  double getUsage(String packageName) => state[packageName] ?? 0;

  double get totalMinutes =>
      state.values.fold(0.0, (sum, m) => sum + m);
}

/// 历史使用数据（用于统计页面）
class UsageHistoryNotifier
    extends StateNotifier<Map<String, Map<String, double>>> {
  UsageHistoryNotifier() : super({});

  /// 加载指定天数范围的历史数据
  Future<void> loadRange(int days) async {
    final dates = AppUtils.pastDays(days);
    final startDate = dates.first;
    final endDate = dates.last;
    final data = await DatabaseHelper.getUsageByDateRange(startDate, endDate);
    state = {
      'total': data,
    };
  }

  Future<void> loadDailyTotals(int days) async {
    final result = await DatabaseHelper.getDailyTotalUsage(days);
    final map = <String, double>{};
    for (final row in result) {
      map[row['date'] as String] = (row['total'] as num).toDouble();
    }
    state = {...state, 'daily': map};
  }
}

final todayUsageProvider =
    StateNotifierProvider<TodayUsageNotifier, Map<String, double>>(
        (ref) => TodayUsageNotifier());

final usageHistoryProvider = StateNotifierProvider<UsageHistoryNotifier,
    Map<String, Map<String, double>>>((ref) => UsageHistoryNotifier());
