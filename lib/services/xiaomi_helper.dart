import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:usage_stats/usage_stats.dart';

/// 小米/澎湃 OS 适配工具
class XiaomiHelper {
  /// 检测是否为小米设备
  static Future<bool> isXiaomiDevice() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.manufacturer.toLowerCase().contains('xiaomi') ||
        info.manufacturer.toLowerCase().contains('redmi') ||
        info.brand.toLowerCase().contains('poco');
  }

  /// 检测使用统计权限是否已授予
  static Future<bool> hasUsageStatsPermission() async {
    final status = await UsageStats.checkUsagePermission();
    return status ?? false;
  }

  /// 请求使用统计权限（跳转系统设置）
  static Future<void> requestUsageStatsPermission() async {
    await UsageStats.grantUsagePermission();
  }

  /// 检测通知权限
  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// 请求通知权限
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 打开应用设置页面
  static Future<void> openAppSettingsPage() async {
    await AppSettings.openAppSettings();
  }

  /// 打开电池优化设置
  /// 注意：app_settings 包不支持直接跳转电池优化页，打开通用设置页后用户需手动导航
  static Future<void> openBatteryOptimizationSettings() async {
    await AppSettings.openAppSettings();
  }

  /// 打开自启动管理
  /// 注意：小米自启动管理需要特定 Intent，app_settings 包不支持
  /// 打开通用应用设置页，用户需手动进入自启动管理
  static Future<void> openAutoStartSettings() async {
    await AppSettings.openAppSettings();
  }

  /// 获取小米适配引导文案
  static Future<List<XiaomiGuideStep>> getGuideSteps() async {
    final isXiaomi = await isXiaomiDevice();
    final steps = <XiaomiGuideStep>[];

    steps.add(XiaomiGuideStep(
      title: '授予使用统计权限',
      description: '允许 TimeGuard 读取应用使用时间数据',
      action: 'usage_stats',
      isRequired: true,
    ));

    steps.add(XiaomiGuideStep(
      title: '允许通知',
      description: '接收超时提醒和专注模式通知',
      action: 'notification',
      isRequired: true,
    ));

    if (isXiaomi) {
      steps.addAll([
        XiaomiGuideStep(
          title: '开启自启动',
          description: '设置 → 应用管理 → TimeGuard → 自启动 → 开启',
          action: 'auto_start',
          isRequired: true,
        ),
        XiaomiGuideStep(
          title: '关闭省电限制',
          description: '设置 → 应用管理 → TimeGuard → 省电策略 → 无限制',
          action: 'battery_optimization',
          isRequired: true,
        ),
        XiaomiGuideStep(
          title: '锁定最近任务',
          description: '在最近任务界面下拉 TimeGuard 卡片，点击锁定图标',
          action: 'lock_recent',
          isRequired: false,
        ),
      ]);
    }

    return steps;
  }
}

/// 引导步骤
class XiaomiGuideStep {
  final String title;
  final String description;
  final String action;
  final bool isRequired;

  XiaomiGuideStep({
    required this.title,
    required this.description,
    required this.action,
    this.isRequired = false,
  });
}
