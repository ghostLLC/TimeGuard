import 'dart:async';
import 'package:usage_stats/usage_stats.dart';
import '../database/database_helper.dart';
import '../models/app_limit.dart';
import '../models/category.dart';
import '../models/daily_usage.dart';
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

  // 缓存：限额和分类
  Map<String, AppLimit> _limitCache = {};
  Map<int, AppCategory> _categoryCache = {};
  // 分类 → 所属应用包名列表（含无独立限额的应用）
  Map<int, List<String>> _categoryAppsCache = {};

  void Function(String packageName, double totalMinutes)? onUsageUpdated;
  void Function(String packageName, double usedMinutes, int limitMinutes)?
      onOvertime;
  void Function(String categoryName, double usedMinutes, int limitMinutes)?
      onCategoryOvertime;

  final Map<String, DateTime> _lastOvertimeNotification = {};
  final Map<String, DateTime> _lastCategoryOvertimeNotification = {};

  bool get isRunning => _trackingTimer?.isActive ?? false;

  Future<void> start() async {
    if (_trackingTimer?.isActive ?? false) return;
    await _preloadTodayUsage();
    await _refreshCache();
    _lastCheckTime = DateTime.now();
    _trackingTimer = Timer.periodic(
      Duration(seconds: AppConstants.trackingIntervalSeconds),
      (_) => _pollUsage(),
    );
  }

  Future<void> _preloadTodayUsage() async {
    final today = AppUtils.todayString();
    final usages = await DatabaseHelper.getDailyUsage(today);
    for (final u in usages) {
      _sessionUsage[u.packageName] = u.usageMinutes;
      if (u is DailyUsageWithPeriods) {
        _morningUsage[u.packageName] = u.morningMinutes;
        _afternoonUsage[u.packageName] = u.afternoonMinutes;
        _eveningUsage[u.packageName] = u.eveningMinutes;
      }
    }
  }

  Future<void> _refreshCache() async {
    final limits = await DatabaseHelper.getAppLimits();
    _limitCache = {for (final l in limits) l.packageName: l};

    final categories = await DatabaseHelper.getCategories();
    _categoryCache = {for (final c in categories) if (c.id != null) c.id!: c};

    // 构建分类 → 应用列表（包括通过 packageCategoryMap 映射的）
    _categoryAppsCache = {};
    for (final limit in limits) {
      if (limit.categoryId != null) {
        _categoryAppsCache
            .putIfAbsent(limit.categoryId!, () => [])
            .add(limit.packageName);
      }
    }
    // 加入没有独立限额但通过预设映射属于某分类的应用
    for (final entry in AppConstants.packageCategoryMap.entries) {
      final cat = categories.where((c) => c.name == entry.value).firstOrNull;
      if (cat?.id != null && !_limitCache.containsKey(entry.key)) {
        _categoryAppsCache
            .putIfAbsent(cat!.id!, () => [])
            .add(entry.key);
      }
    }
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

      // 只匹配 RESUMED 事件（API 29+: eventType=2）
      String? currentForeground;
      for (final event in events.reversed) {
        if (event.eventType == 2) {
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

        // 持久化（含时段数据）
        await DatabaseHelper.upsertDailyUsageWithPeriods(
          date: AppUtils.todayString(),
          packageName: currentForeground,
          totalMinutes: _sessionUsage[currentForeground]!,
          morningMinutes: _morningUsage[currentForeground] ?? 0,
          afternoonMinutes: _afternoonUsage[currentForeground] ?? 0,
          eveningMinutes: _eveningUsage[currentForeground] ?? 0,
        );

        onUsageUpdated?.call(
            currentForeground, _sessionUsage[currentForeground]!);

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

  void _checkAppLimitFromCache(
      String packageName, double usedMinutes, TimePeriod period) {
    final limit = _limitCache[packageName];
    if (limit == null || !limit.isActive) return;

    if (usedMinutes >= limit.dailyLimitMinutes) {
      _notifyOvertime(packageName, usedMinutes, limit.dailyLimitMinutes);
      return;
    }

    final periodLimit = limit.getLimitForPeriod(period);
    if (periodLimit != null) {
      final periodUsage = getPeriodUsage(packageName, period);
      if (periodUsage >= periodLimit) {
        _notifyOvertime(packageName, periodUsage, periodLimit);
      }
    }
  }

  /// 检查分类限额 — 包含所有属于该分类的应用（含无独立限额的）
  void _checkCategoryLimitFromCache(String packageName) {
    final limit = _limitCache[packageName];
    if (limit?.categoryId == null) return;

    final category = _categoryCache[limit!.categoryId!];
    if (category == null || category.dailyLimitMinutes == null) return;

    double categoryTotal = 0;
    final apps = _categoryAppsCache[category.id!] ?? [];
    for (final pkg in apps) {
      categoryTotal += _sessionUsage[pkg] ?? 0;
    }

    if (categoryTotal >= category.dailyLimitMinutes!) {
      _notifyCategoryOvertime(
          category.name, categoryTotal, category.dailyLimitMinutes!);
    }
  }

  void _notifyOvertime(
      String packageName, double usedMinutes, int limitMinutes) {
    final lastNotif = _lastOvertimeNotification[packageName];
    final now = DateTime.now();
    if (lastNotif != null &&
        now.difference(lastNotif).inSeconds <
            AppConstants.defaultOvertimeIntervalMinutes * 60) {
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
        now.difference(lastNotif).inSeconds <
            AppConstants.defaultOvertimeIntervalMinutes * 60) {
      return;
    }
    _lastCategoryOvertimeNotification[categoryName] = now;
    onCategoryOvertime?.call(categoryName, usedMinutes, limitMinutes);
  }

  /// 系统包名过滤 — 仅排除真正的系统组件，不排除 Google 应用
  bool _isSystemPackage(String packageName) {
    return packageName == 'com.android.systemui' ||
        packageName == 'com.android.settings' ||
        packageName == 'com.android.launcher' ||
        packageName == 'com.android.launcher3' ||
        packageName.startsWith('com.miui.') ||
        packageName.startsWith('com.xiaomi.') ||
        packageName == 'com.google.android.gms' ||
        packageName == 'com.google.android.gsf' ||
        packageName.contains('timeguard');
  }
}
