import '../database/database_helper.dart';
import '../core/constants.dart';
import '../models/achievement.dart';
import '../providers/achievement_provider.dart';

/// 成就检测器 — 每日/每次操作后调用
class AchievementChecker {
  /// 每日检测（在每日复盘时调用）
  static Future<void> checkDailyAchievements() async {
    await _checkDisciplineDayStreak();
    await _checkFocusTotal();
  }

  /// 检测自律日连续天数相关成就
  static Future<void> _checkDisciplineDayStreak() async {
    final streak = await DatabaseHelper.getConsecutiveDisciplineDays();

    if (streak >= 1) {
      await _tryUnlock('first_discipline_day');
    }
    if (streak >= 3) {
      await _tryUnlock('three_day_streak');
    }
    if (streak >= 7) {
      await _tryUnlock('week_streak');
    }
    if (streak >= 30) {
      await _tryUnlock('month_streak');
    }
  }

  /// 检测专注时长成就
  static Future<void> _checkFocusTotal() async {
    final totalMinutes = await DatabaseHelper.getTotalFocusMinutes();
    if (totalMinutes >= 6000) {
      // 100 hours
      await _tryUnlock('focus_100h');
    }
  }

  /// 检测超时后快速切走（回头是岸）
  /// 在超时通知发出后，如果用户在 60 秒内切走，触发此方法
  static Future<void> checkQuickRecovery() async {
    await _tryUnlock('quick_recovery');
  }

  /// 检测社交戒断（需要单独追踪社交类应用连续达标天数）
  static Future<void> checkSocialDetox() async {
    // 简化实现：检查过去 7 天是否所有社交类应用均未超时
    // 完整版需要每日记录每个分类的达标状态
    final today = DateTime.now();
    bool allClean = true;

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dd = await DatabaseHelper.getDailyDiscipline(dateStr);
      if (dd == null || !dd.allLimitsMet) {
        allClean = false;
        break;
      }
    }

    if (allClean) {
      await _tryUnlock('social_detox_7d');
    }
  }

  /// 尝试解锁成就（幂等）
  static Future<void> _tryUnlock(String key) async {
    final alreadyUnlocked = await DatabaseHelper.isAchievementUnlocked(key);
    if (alreadyUnlocked) return;

    await DatabaseHelper.unlockAchievement(key);
    await DatabaseHelper.addPoints(
      AppConstants.pointsAchievement,
      'achievement:$key',
    );
  }

  /// 每日复盘：更新当日自律状态
  static Future<void> recordDailyDiscipline({
    required String date,
    required bool allLimitsMet,
    required double totalScreenMinutes,
    required int focusSessionsCount,
    required double focusTotalMinutes,
  }) async {
    final existing = await DatabaseHelper.getDailyDiscipline(date);
    if (existing != null && existing.allLimitsMet && !allLimitsMet) {
      // 已从达标变为不达标，不覆盖
      return;
    }

    await DatabaseHelper.upsertDailyDiscipline(
      DailyDiscipline(
        date: date,
        allLimitsMet: allLimitsMet,
        totalScreenMinutes: totalScreenMinutes,
        focusSessionsCount: focusSessionsCount,
        focusTotalMinutes: focusTotalMinutes,
      ).copyWith(id: existing?.id),
    );

    if (allLimitsMet) {
      await DatabaseHelper.addPoints(
        AppConstants.pointsDisciplineDay,
        'discipline_day:$date',
      );
    }
  }
}

/// DailyDiscipline copyWith 扩展
extension DailyDisciplineCopyWith on DailyDiscipline {
  DailyDiscipline copyWith({int? id}) {
    return DailyDiscipline(
      id: id ?? this.id,
      date: date,
      allLimitsMet: allLimitsMet,
      totalScreenMinutes: totalScreenMinutes,
      focusSessionsCount: focusSessionsCount,
      focusTotalMinutes: focusTotalMinutes,
    );
  }
}
