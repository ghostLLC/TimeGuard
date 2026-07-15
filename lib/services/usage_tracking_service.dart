import 'dart:async';
import 'package:usage_stats/usage_stats.dart';
import '../database/database_helper.dart';
import '../models/app_limit.dart';
import '../models/category.dart';
import '../core/constants.dart';
import '../core/utils.dart';

/// 应用使用时长追踪服务
class UsageTrackingService {
  Timer? _trackingTimer;
  String? _lastForegroundPackage;
  DateTime? _lastCheckTime;

  // 全天累计（分钟）
  final Map<String, double> _sessionUsage = {};
  // 按时段独立累计
  final Map<String, double> _morningUsage = {};
  final Map<String, double> _afternoonUsage = {};
  final Map<String, double> _eveningUsage = {};

  // 缓存：限额和分类（避免每次轮询都查 DB）
  Map<String, AppLimit> _limitCache = {};
  Map<int, AppCategory> _categoryCache = {};

  void Function(String packageName, double totalMinutes)? onUsageUpdated;
  void Function(String packageName, double usedMinutes, int limitMinutes)?
      onOvertime;
  void Function(String categoryName, double usedMinutes, int limitMinutes)?
      onCategoryOvertime;

  final Map<String, DateTime> _lastOvertimeNotification = {};
  final Map<String, DateTime> _lastCategoryOvertimeNotification = {};
  // 通知 ID 分配表（避免 hashCode 冲突）
  final Map<String, int> _notificationIds = {};
  int _nextNotificationId = 5000;

  bool get isRunning => _trackingTimer?.isActive ?? false;

  /// 启动追踪
  Future<void> start() async {
    if (_trackingTimer?.isActive ?? false) return;

    // 从数据库预加载今日已有数据（修复重启后数据丢失）
    await _preloadTodayUsage();
    // 缓存限额配置（避免每轮查 DB）
    await _refreshCache();

    _lastCheckTime = DateTime.now();
    _trackingTimer = Timer.periodic(
      Duration(seconds: AppConstants.trackingIntervalSeconds),
      (_) => _pollUsage(),
    );
  }

  /// 从数据库预加载今日使用数据
  Future<void> _preloadTodayUsage() async {
    final today = AppUtils.todayString();
    final usages = await DatabaseHelper.getDailyUsage(today);
    for (final u in usages) {
      _sessionUsage[u.packageName] = u.usageMinutes;
    }
  }

  /// 刷新限额和分类缓存
  Future<void> _refreshCache() async {
    final limits = await DatabaseHelper.getAppLimits();
    _limitCache = {for (final l in limits) l.packageName: l};
    final categories = await DatabaseHelper.getCategories();
    _categoryCache = {for (final c in categories) c.id!: c};
  }

  void stop() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  void resetDaily() {
    _sessionUsage.clear();
    _morningUsage.clear();
    _afternoonUsage.clear();
    _eveningUsage.clear();
    _lastOvertimeNotification.clear();
    _lastCategoryOvertimeNotification.clear();
  }

  double getSessionUsage(String packageName) =>
      _sessionUsage[packageName] ?? 0;

  Map<String, double> getAllSessionUsage() => Map.from(_sessionUsage);

  /// 获取指定时段的累计使用时长
  double getPeriodUsage(String packageName, TimePeriod period) {
    switch (period) {
      case TimePeriod.morning:
        return _morningUsage[packageName] ?? 0;
      case TimePeriod.afternoon:
        return _afternoonUsage[packageName] ?? 0;
      case TimePeriod.evening:
        return _eveningUsage[packageName] ?? 0;
    }
  }

  Future<void> _pollUsage() async {
    try {
      final now = DateTime.now();
      final start = _lastCheckTime ??
          now.subtract(Duration(seconds: AppConstants.trackingIntervalSeconds));

      final events = await UsageStats.queryEvents(start, now);

      if (events.isEmpty) {
        _lastCheckTime = now;
        return;
      }

      // 分析前台应用
      String? currentForeground;
      for (final event in events.reversed) {
        // API 29+: ACTIVITY_RESUMED=2, ACTIVITY_PAUSED=1
        // API <29: MOVE_TO_FOREGROUND=1, MOVE_TO_BACKGROUND=2
        if (event.eventType == 1 || event.eventType == 2) {
          currentForeground = event.packageName;
          break;
        }
      }
      currentForeground ??= events.last.packageName;

      final elapsed = now.difference(start);
      final elapsedMinutes = elapsed.inMilliseconds / 60000.0;

      if (currentForeground != null &&
          !_isSystemPackage(currentForeground)) {
        // 更新全天累计
        _sessionUsage[currentForeground] =
            (_sessionUsage[currentForeground] ?? 0) + elapsedMinutes;

        // 更新当前时段累计
        final period = TimePeriodExtension.fromHour(now.hour);
        final periodMap = _getPeriodMap(period);
        periodMap[currentForeground] =
            (periodMap[currentForeground] ?? 0) + elapsedMinutes;

        // 持久化到数据库
        await DatabaseHelper.upsertDailyUsage(
          AppUtils.todayString(),
          currentForeground,
          _sessionUsage[currentForeground]!,
        );

        onUsageUpdated?.call(
            currentForeground, _sessionUsage[currentForeground]!);

        // 检查限额（使用缓存）
        _checkAppLimitFromCache(
            currentForeground, _sessionUsage[currentForeground]!, period);
        _checkCategoryLimitFromCache(currentForeground);
      }

      _lastForegroundPackage = currentForeground;
      _lastCheckTime = now;
    } catch (_) {
      _lastCheckTime = DateTime.now();
    }
  }

  Map<String, double> _getPeriodMap(TimePeriod period) {
    switch (period) {
      case TimePeriod.morning:
        return _morningUsage;
      case TimePeriod.afternoon:
        return _afternoonUsage;
      case TimePeriod.evening:
        return _eveningUsage;
    }
  }

  /// 检查应用限额（使用缓存，避免 DB 查询）
  void _checkAppLimitFromCache(
      String packageName, double usedMinutes, TimePeriod period) {
    final limit = _limitCache[packageName];
    if (limit == null || !limit.isActive) return;

    // 每日限额
    if (usedMinutes >= limit.dailyLimitMinutes) {
      _notifyOvertime(packageName, usedMinutes, limit.dailyLimitMinutes);
      return;
    }

    // 时段限额
    final periodLimit = limit.getLimitForPeriod(period);
    if (periodLimit != null) {
      final periodUsage = getPeriodUsage(packageName, period);
      if (periodUsage >= periodLimit) {
        _notifyOvertime(packageName, periodUsage, periodLimit);
      }
    }
  }

  /// 检查分类限额（使用缓存）
  void _checkCategoryLimitFromCache(String packageName) {
    final limit = _limitCache[packageName];
    if (limit?.categoryId == null) return;

    final category = _categoryCache[limit!.categoryId!];
    if (category == null || category.dailyLimitMinutes == null) return;

    double categoryTotal = 0;
    for (final entry in _limitCache.entries) {
      if (entry.value.categoryId == category.id) {
        categoryTotal += _sessionUsage[entry.key] ?? 0;
      }
    }

    if (categoryTotal >= category.dailyLimitMinutes!) {
      _notifyCategoryOvertime(
          category.name, categoryTotal, category.dailyLimitMinutes!);
    }
  }

  /// 获取唯一通知 ID（避免 hashCode 冲突）
  int getNotificationId(String key) {
    return _notificationIds.putIfAbsent(key, () => _nextNotificationId++);
  }

  void _notifyOvertime(
      String packageName, double usedMinutes, int limitMinutes) {
    final lastNotif = _lastOvertimeNotification[packageName];
    final now = DateTime.now();
    if (lastNotif != null &&
        now.difference(lastNotif).inMinutes <
            AppConstants.defaultOvertimeIntervalMinutes) {
      return;
    }
    _lastOvertimeNotification[packageName] = now;
    onOvertime?.call(packageName, usedMinutes, limitMinutes);
  }

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

  bool _isSystemPackage(String packageName) {
    return packageName.startsWith('com.android.') ||
        packageName.startsWith('com.miui.') ||
        packageName.startsWith('com.xiaomi.') ||
        packageName == 'com.google.android.launcher' ||
        packageName == 'com.android.systemui' ||
        packageName == 'com.android.settings' ||
        packageName.contains('timeguard');
  }
}
