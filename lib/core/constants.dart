/// TimeGuard 应用常量
class AppConstants {
  static const String appName = '时用 TimeGuard';
  static const String appVersion = '1.0.0';

  // ── 时段定义 ──
  static const int morningStart = 6;   // 上午开始 06:00
  static const int afternoonStart = 12; // 下午开始 12:00
  static const int eveningStart = 18;  // 晚上开始 18:00
  static const int nightEnd = 24;      // 夜间结束 24:00 (次日 00:00)

  // ── 计时器 ──
  static const int trackingIntervalSeconds = 10;  // 轮询间隔（秒）
  static const int defaultOvertimeIntervalMinutes = 5; // 超时后重复提醒间隔

  // ── 专注模式预设时长（分钟） ──
  static const List<int> focusPresets = [25, 45, 60, 90, 120];

  // ── 积分规则 ──
  static const int pointsFocusComplete = 10;
  static const int pointsDisciplineDay = 20;
  static const int pointsAchievement = 50;

  // ── 预设分类 ──
  static const List<Map<String, dynamic>> defaultCategories = [
    {'name': '社交', 'iconName': 'chat', 'colorHex': '#6366F1'},
    {'name': '娱乐', 'iconName': 'play_circle', 'colorHex': '#EC4899'},
    {'name': '学习', 'iconName': 'school', 'colorHex': '#10B981'},
    {'name': '购物', 'iconName': 'shopping_bag', 'colorHex': '#F59E0B'},
    {'name': '工具', 'iconName': 'build', 'colorHex': '#6B7280'},
  ];

  // ── 常见应用分类映射 ──
  static const Map<String, String> packageCategoryMap = {
    // 社交
    'com.tencent.mm': '社交',         // 微信
    'com.tencent.mobileqq': '社交',   // QQ
    'com.sina.weibo': '社交',         // 微博
    'com.xingin.xhs': '社交',        // 小红书
    'com.immomo.momo': '社交',        // 陌陌
    'com.ss.android.ugc.aweme': '娱乐', // 抖音
    'tv.danmaku.bili': '娱乐',        // B站
    'com.youku.phone': '娱乐',        // 优酷
    'com.tencent.qqlive': '娱乐',     // 腾讯视频
    'com.qiyi.video': '娱乐',         // 爱奇艺
    'com.netease.cloudmusic': '娱乐', // 网易云音乐
    'com.tencent.qqmusic': '娱乐',    // QQ音乐
    // 学习
    'com.netease.edu.ucmooc': '学习', // 网易公开课
    'com.baidu.baidutranslate': '学习', // 百度翻译
    // 购物
    'com.taobao.taobao': '购物',      // 淘宝
    'com.jingdong.app.mall': '购物',  // 京东
    'com.xunmeng.pinduoduo': '购物',  // 拼多多
    // 工具
    'com.tencent.wps': '工具',        // WPS
  };

  // ── 通知 ID ──
  static const int notificationChannelOvertime = 1001;
  static const int notificationChannelFocus = 1002;
  static const int notificationChannelDaily = 1003;
  static const int notificationChannelForeground = 2001;

  // ── SharedPreferences Keys ──
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyAutoStartChecked = 'auto_start_checked';
  static const String keyStrictMode = 'strict_mode';
  static const String keyDailyReviewHour = 'daily_review_hour';
  static const String keyDailyReviewMinute = 'daily_review_minute';
}

/// 时段枚举
enum TimePeriod {
  morning,   // 06:00 - 12:00
  afternoon, // 12:00 - 18:00
  evening,   // 18:00 - 24:00
}

extension TimePeriodExtension on TimePeriod {
  String get label {
    switch (this) {
      case TimePeriod.morning:
        return '上午';
      case TimePeriod.afternoon:
        return '下午';
      case TimePeriod.evening:
        return '晚上';
    }
  }

  int get startHour {
    switch (this) {
      case TimePeriod.morning:
        return AppConstants.morningStart;
      case TimePeriod.afternoon:
        return AppConstants.afternoonStart;
      case TimePeriod.evening:
        return AppConstants.eveningStart;
    }
  }

  int get endHour {
    switch (this) {
      case TimePeriod.morning:
        return AppConstants.afternoonStart;
      case TimePeriod.afternoon:
        return AppConstants.eveningStart;
      case TimePeriod.evening:
        return AppConstants.nightEnd;
    }
  }

  /// 根据当前小时获取时段
  static TimePeriod fromHour(int hour) {
    if (hour >= AppConstants.morningStart && hour < AppConstants.afternoonStart) {
      return TimePeriod.morning;
    } else if (hour >= AppConstants.afternoonStart && hour < AppConstants.eveningStart) {
      return TimePeriod.afternoon;
    } else {
      return TimePeriod.evening;
    }
  }
}
