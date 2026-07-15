import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/constants.dart';
import '../core/utils.dart';

/// 通知服务 — 封装 flutter_local_notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 创建通知渠道
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'overtime_channel',
          '超时提醒',
          description: '当应用使用超时时发送通知',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'focus_channel',
          '专注模式',
          description: '专注模式提醒',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_channel',
          '每日复盘',
          description: '每日使用报告',
          importance: Importance.defaultImportance,
          playSound: false,
        ),
      );
    }

    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    // 点击通知后的处理（可扩展：跳转到对应页面）
  }

  /// 发送超时通知
  static Future<void> sendOvertimeNotification(
    String appName,
    double usedMinutes,
    int limitMinutes,
  ) async {
    if (!_initialized) return;

    final androidDetails = const AndroidNotificationDetails(
      'overtime_channel',
      '超时提醒',
      channelDescription: '当应用使用超时时发送通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      AppConstants.notificationChannelOvertime + appName.hashCode % 1000,
      '$appName 使用超时',
      '已使用 ${AppUtils.formatMinutes(usedMinutes)}，'
      '超过每日限额 ${AppUtils.formatMinutes(limitMinutes.toDouble())}',
      NotificationDetails(android: androidDetails),
    );
  }

  /// 发送分类超时通知
  static Future<void> sendCategoryOvertimeNotification(
    String categoryName,
    double usedMinutes,
    int limitMinutes,
  ) async {
    if (!_initialized) return;

    await _plugin.show(
      AppConstants.notificationChannelOvertime + categoryName.hashCode % 1000,
      '$categoryName 类应用超时',
      '已使用 ${AppUtils.formatMinutes(usedMinutes)}，'
      '超过分类限额 ${AppUtils.formatMinutes(limitMinutes.toDouble())}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'overtime_channel',
          '超时提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// 发送专注模式提醒
  static Future<void> sendFocusReminder(
    String appName,
    int remainingMinutes,
  ) async {
    if (!_initialized) return;

    await _plugin.show(
      AppConstants.notificationChannelFocus,
      '专注中',
      '还剩 ${remainingMinutes}m，请放下 $appName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_channel',
          '专注模式',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// 发送专注完成通知
  static Future<void> sendFocusComplete(int durationMinutes) async {
    if (!_initialized) return;

    await _plugin.show(
      AppConstants.notificationChannelFocus,
      '专注完成！',
      '本次专注 ${AppUtils.formatMinutes(durationMinutes.toDouble())}，+${AppConstants.pointsFocusComplete} 积分',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_channel',
          '专注模式',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  /// 发送每日复盘通知
  static Future<void> sendDailyReview({
    required double totalMinutes,
    required bool allLimitsMet,
    required int streakDays,
  }) async {
    if (!_initialized) return;

    final status = allLimitsMet ? '全部达标！' : '部分超时';
    final streak = streakDays > 0 ? '连续自律 $streakDays 天' : '';

    await _plugin.show(
      AppConstants.notificationChannelDaily,
      '今日复盘 - $status',
      '总屏幕时间 ${AppUtils.formatMinutesChinese(totalMinutes)}'
      '${streak.isNotEmpty ? " | $streak" : ""}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          '每日复盘',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  /// 请求通知权限
  static Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestNotificationsPermission() ?? false;
  }
}
