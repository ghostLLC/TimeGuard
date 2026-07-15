import 'dart:async';
import 'package:collection/collection.dart';
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
  String? _lastDate; // 用于检测跨日

  final Map<String, double> _sessionUsage = {};
  final Map<String, double> _morningUsage = {};
  final Map<String, double> _afternoonUsage = {};
  final Map<String, double> _eveningUsage = {};

  Map<String, AppLimit> _limitCache = {};
  Map<int, AppCategory> _categoryCache = {};
  Map<int, List<String>> _categoryAppsCache = {};
  // 包名 → 分类 ID（用于无独立限额的应用查找分类）
  Map<String, int> _packageCategoryMap = {};

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
    _lastDate = AppUtils.todayString();
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

    _categoryAppsCache = {};
    _packageCategoryMap = {};

    // 从限额中提取分类映射
    for (final limit in limits) {
      if (limit.categoryId != null) {
        _categoryAppsCache
            .putIfAbsent(limit.categoryId!, () => [])
            .add(limit.packageName);
        _packageCategoryMap[limit.packageName] = limit.categoryId!;
      }
    }

    // 加入预设映射中无独立限额的应用
    for (final entry in AppConstants.packageCategoryMap.entries) {
      final cat = categories.where((c) => c.name == entry.value).firstOrNull;
      if (cat?.id != null) {
        _categoryAppsCache
            .putIfAbsent(cat!.id!, () => [])
            .add(entry.key);
        _packageCategoryMap.putIfAbsent(entry.key, () => cat.id!);
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
      final todayDate = AppUtils.todayString();

      // 跨日检测：自动重置
      if (_lastDate != null && _lastDate != todayDate) {
        resetDaily();
        await _preloadTodayUsage(); // 重新加载（可能已有数据）
      }
      _lastDate = todayDate;

      final start = _lastCheckTime ??
          now.subtract(Duration(seconds: AppConstants.trackingIntervalSeconds));

      final events = await UsageStats.queryEvents(start, now);
      if (events.isEmpty) {
        _lastCheckTime = now;
        return;
      }

      // 只匹配 RESUMED 事件
      String? currentForeground;
      for (final event in events.reversed) {
        if (event.eventType == 2) {
          currentForeground = event.packageName;
          break;
        }
      }
      // 无 RESUMED 事件时沿用上次前台应用（而非取 events.last）
      currentForeground ??= _lastForegroundPackage;

      final elapsed = now.difference(start);
      final elapsedMinutes = elapsed.inMilliseconds / 60000.0;

      if (currentForeground != null &&
          !_isSystemPackage(currentForeground)) {
        _sessionUsage[currentForeground] =
            (_sessionUsage[currentForeground] ?? 0) + elapsedMinutes;

        final period = TimePeriodExtension.fromHour(now.hour);
        final periodMap = _getPeriodMap(period);
        periodMap[currentForeground] =
            (periodMap[currentForeground] ?? 0) + elapsedMinutes;

        await DatabaseHelper.upsertDailyUsageWithPeriods(
          date: todayDate,
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
      _notifyOvertime(packageName, usedMinutes, limit.dailyLimitMinutes,
          limit.overtimeIntervalMinutes);
      return;
    }

    final periodLimit = limit.getLimitForPeriod(period);
    if (periodLimit != null) {
      final periodUsage = getPeriodUsage(packageName, period);
      if (periodUsage >= periodLimit) {
        _notifyOvertime(
            packageName, periodUsage, periodLimit, limit.overtimeIntervalMinutes);
      }
    }
  }

  /// 检查分类限额 — 支持无独立限额的应用通过 packageCategoryMap 查找分类
  void _checkCategoryLimitFromCache(String packageName) {
    int? categoryId = _limitCache[packageName]?.categoryId;
    // 无独立限额时，从映射表查找分类
    categoryId ??= _packageCategoryMap[packageName];
    if (categoryId == null) return;

    final category = _categoryCache[categoryId];
    if (category == null || category.dailyLimitMinutes == null) return;

    double categoryTotal = 0;
    final apps = _categoryAppsCache[categoryId] ?? [];
    for (final pkg in apps) {
      categoryTotal += _sessionUsage[pkg] ?? 0;
    }

    if (categoryTotal >= category.dailyLimitMinutes!) {
      _notifyCategoryOvertime(
          category.name, categoryTotal, category.dailyLimitMinutes!);
    }
  }

  void _notifyOvertime(
      String packageName, double usedMinutes, int limitMinutes,
      [int intervalMinutes = AppConstants.defaultOvertimeIntervalMinutes]) {
    final lastNotif = _lastOvertimeNotification[packageName];
    final now = DateTime.now();
    if (lastNotif != null &&
        now.difference(lastNotif).inSeconds < intervalMinutes * 60) {
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
