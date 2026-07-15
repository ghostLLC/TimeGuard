import 'dart:async';
import 'package:usage_stats/usage_stats.dart';
import '../database/database_helper.dart';
import '../core/constants.dart';
import '../core/utils.dart';

/// 应用使用时长追踪服务
/// 通过轮询 UsageStatsManager 检测前台应用并累计使用时长
class UsageTrackingService {
  Timer? _trackingTimer;
  String? _lastForegroundPackage;
  DateTime? _lastCheckTime;
  final Map<String, double> _sessionUsage = {}; // 本轮会话累计（分钟）

  // 回调：当某个应用使用时长更新时
  void Function(String packageName, double totalMinutes)? onUsageUpdated;
  // 回调：当某个应用超时时
  void Function(String packageName, double usedMinutes, int limitMinutes)?
      onOvertime;
  // 回调：当分类超时时
  void Function(String categoryName, double usedMinutes, int limitMinutes)?
      onCategoryOvertime;

  // 超时追踪（避免重复通知）
  final Map<String, DateTime> _lastOvertimeNotification = {};
  final Map<String, DateTime> _lastCategoryOvertimeNotification = {};

  bool get isRunning => _trackingTimer?.isActive ?? false;

  /// 启动追踪
  void start() {
    if (_trackingTimer?.isActive ?? false) return;
    _lastCheckTime = DateTime.now();
    _trackingTimer = Timer.periodic(
      Duration(seconds: AppConstants.trackingIntervalSeconds),
      (_) => _pollUsage(),
    );
  }

  /// 停止追踪
  void stop() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  /// 重置当日累计
  void resetDaily() {
    _sessionUsage.clear();
    _lastOvertimeNotification.clear();
    _lastCategoryOvertimeNotification.clear();
  }

  /// 获取某个应用今日累计使用分钟数
  double getSessionUsage(String packageName) {
    return _sessionUsage[packageName] ?? 0;
  }

  /// 获取所有应用今日累计
  Map<String, double> getAllSessionUsage() => Map.from(_sessionUsage);

  /// 轮询检测前台应用
  Future<void> _pollUsage() async {
    try {
      final now = DateTime.now();
      final start = _lastCheckTime ?? now.subtract(
          Duration(seconds: AppConstants.trackingIntervalSeconds));

      // 查询使用事件
      final events = await UsageStats.queryEvents(start, now);

      if (events.isEmpty) {
        _lastCheckTime = now;
        return;
      }

      // 分析前台应用
      String? currentForeground;
      for (final event in events.reversed) {
        if (event.eventType == 1 || event.eventType == 2) {
          // ACTIVITY_RESUMED = 2, ACTIVITY_PAUSED = 1 (API 29+)
          // 我们使用 eventType 2 来检测前台应用
          currentForeground = event.packageName;
          if (event.eventType == 2) break;
        }
      }

      // 如果找不到明确的前台应用，用最后一个事件
      currentForeground ??= events.last.packageName;

      // 计算经过时间
      final elapsed = now.difference(start);
      final elapsedMinutes = elapsed.inMilliseconds / 60000.0;

      // 如果有一个有效的前台应用（排除系统 UI）
      if (currentForeground != null &&
          !_isSystemPackage(currentForeground)) {
        final current = _sessionUsage[currentForeground] ?? 0;
        _sessionUsage[currentForeground] = current + elapsedMinutes;

        // 持久化到数据库
        await DatabaseHelper.upsertDailyUsage(
          AppUtils.todayString(),
          currentForeground,
          _sessionUsage[currentForeground]!,
        );

        // 通知 UI 更新
        onUsageUpdated?.call(
            currentForeground, _sessionUsage[currentForeground]!);

        // 检查应用限额
        await _checkAppLimit(currentForeground, _sessionUsage[currentForeground]!);

        // 检查分类限额
        await _checkCategoryLimit(currentForeground, now);
      }

      _lastForegroundPackage = currentForeground;
      _lastCheckTime = now;
    } catch (e) {
      // 静默处理异常（权限未授予等）
      _lastCheckTime = DateTime.now();
    }
  }

  /// 检查单个应用限额
  Future<void> _checkAppLimit(String packageName, double usedMinutes) async {
    final limit = await DatabaseHelper.getAppLimitByPackage(packageName);
    if (limit == null || !limit.isActive) return;

    // 检查每日限额
    if (usedMinutes >= limit.dailyLimitMinutes) {
      _notifyOvertime(packageName, usedMinutes, limit.dailyLimitMinutes);
      return;
    }

    // 检查时段限额
    final period = TimePeriodExtension.fromHour(DateTime.now().hour);
    final periodLimit = limit.getLimitForPeriod(period);
    if (periodLimit != null) {
      final periodUsage = _getPeriodUsage(packageName, period);
      if (periodUsage >= periodLimit) {
        _notifyOvertime(packageName, periodUsage, periodLimit);
      }
    }
  }

  /// 检查分类限额
  Future<void> _checkCategoryLimit(String packageName, DateTime now) async {
    final limit = await DatabaseHelper.getAppLimitByPackage(packageName);
    if (limit?.categoryId == null) return;

    final category = await DatabaseHelper.getCategoryById(limit!.categoryId!);
    if (category == null || category.dailyLimitMinutes == null) return;

    // 计算该分类下所有应用总使用时长
    double categoryTotal = 0;
    final allLimits = await DatabaseHelper.getAppLimits();
    for (final appLimit in allLimits) {
      if (appLimit.categoryId == category.id) {
        categoryTotal += _sessionUsage[appLimit.packageName] ?? 0;
      }
    }

    if (categoryTotal >= category.dailyLimitMinutes!) {
      _notifyCategoryOvertime(
          category.name, categoryTotal, category.dailyLimitMinutes!);
    }
  }

  /// 获取某时段使用时长（简化计算：按时段小时占比估算）
  double _getPeriodUsage(String packageName, TimePeriod period) {
    // 简化实现：如果当前在这个时段，返回本次会话累计
    // 完整实现需要按时段独立累计
    final currentPeriod = TimePeriodExtension.fromHour(DateTime.now().hour);
    if (period == currentPeriod) {
      return _sessionUsage[packageName] ?? 0;
    }
    return 0;
  }

  /// 发送超时通知（防重复）
  void _notifyOvertime(
      String packageName, double usedMinutes, int limitMinutes) {
    final lastNotif = _lastOvertimeNotification[packageName];
    final now = DateTime.now();
    if (lastNotif != null &&
        now.difference(lastNotif).inMinutes <
            AppConstants.defaultOvertimeIntervalMinutes) {
      return; // 未到重复通知时间
    }
    _lastOvertimeNotification[packageName] = now;
    onOvertime?.call(packageName, usedMinutes, limitMinutes);
  }

  /// 发送分类超时通知
  void _notifyCategoryOvertime(
      String categoryName, double usedMinutes, int limitMinutes) {
    final lastNotif = _lastCategoryOvertimeNotification[categoryName];
    final now = DateTime.now();
    if (lastNotif != null &&
        now.difference(lastNotif).inMinutes <
            AppConstants.defaultOvertimeIntervalMinutes) {
      return;
    }
    _lastCategoryOvertimeNotification[categoryName] = now;
    onCategoryOvertime?.call(categoryName, usedMinutes, limitMinutes);
  }

  /// 过滤系统包名
  bool _isSystemPackage(String packageName) {
    return packageName.startsWith('com.android.') ||
        packageName.startsWith('com.miui.') ||
        packageName.startsWith('com.xiaomi.') ||
        packageName == 'com.google.android.launcher' ||
        packageName == 'com.android.systemui' ||
        packageName == 'com.android.settings' ||
        packageName.contains('timeguard'); // 排除自身
  }
}
