import 'package:intl/intl.dart';

class AppUtils {
  /// 将 Duration 格式化为 "Xh Ym" 或 "Ym"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// 将分钟数格式化为 "Xh Ym" 或 "Ym"
  static String formatMinutes(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m';
  }

  /// 将分钟数格式化为 "X小时Y分钟"
  static String formatMinutesChinese(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h > 0 && m > 0) {
      return '$h小时$m分钟';
    } else if (h > 0) {
      return '$h小时';
    }
    return '$m分钟';
  }

  /// 获取今天的日期字符串 YYYY-MM-DD
  static String todayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// 获取昨天的日期字符串
  static String yesterdayString() {
    return DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
  }

  /// 获取过去 N 天的日期列表
  static List<String> pastDays(int days) {
    return List.generate(days, (i) {
      return DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: days - 1 - i)));
    });
  }

  /// 计算百分比（安全除法）
  static double percentage(double value, double total) {
    if (total <= 0) return 0;
    return (value / total * 100).clamp(0, 100);
  }

  /// 颜色十六进制转 Color
  static int colorFromHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return int.parse(hex, radix: 16);
  }

  /// Color 转十六进制
  static String colorToHex(int color) {
    return '#${color.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// 获取进度条颜色
  static int progressColor(double used, double limit) {
    if (limit <= 0) return 0xFF6366F1;
    final ratio = used / limit;
    if (ratio >= 1.0) return 0xFFEF4444;      // 红色 - 超时
    if (ratio >= 0.8) return 0xFFF59E0B;      // 黄色 - 接近上限
    return 0xFF6366F1;                          // 主题色 - 正常
  }

  /// 截断应用名称（过长时加省略号）
  static String truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  /// 格式化倒计时秒数 → "MM:SS"
  static String formatCountdown(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 格式化倒计时 → "HH:MM:SS"
  static String formatCountdownLong(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
