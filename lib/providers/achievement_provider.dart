import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement.dart';
import '../database/database_helper.dart';
import '../core/constants.dart';

/// 成就状态管理
class AchievementsNotifier extends StateNotifier<List<Achievement>> {
  AchievementsNotifier() : super(AchievementCatalog.all) {
    _init();
  }

  Future<void> _init() async {
    try { await load(); } catch (_) {}
  }

  Future<void> load() async {
    final dbData = await DatabaseHelper.getAchievements();
    final unlocked = <String, bool>{};
    for (final row in dbData) {
      unlocked[row['badge_key'] as String] =
          (row['is_unlocked'] as int) == 1;
    }
    state = AchievementCatalog.all.map((a) {
      final isUnlocked = unlocked[a.key] ?? false;
      return a.copyWith(isUnlocked: isUnlocked);
    }).toList();
  }

  Future<void> checkAndUnlock(String key) async {
    final alreadyUnlocked = await DatabaseHelper.isAchievementUnlocked(key);
    if (alreadyUnlocked) return;

    await DatabaseHelper.unlockAchievement(key);
    await DatabaseHelper.addPoints(
      AppConstants.pointsAchievement,
      'achievement:$key',
    );
    await load();
  }

  int get unlockedCount => state.where((a) => a.isUnlocked).length;
}

/// 积分状态
class PointsNotifier extends StateNotifier<int> {
  PointsNotifier() : super(0) {
    _init();
  }

  Future<void> _init() async {
    try { await load(); } catch (_) {}
  }

  Future<void> load() async {
    state = await DatabaseHelper.getTotalPoints();
  }

  Future<void> refresh() async {
    state = await DatabaseHelper.getTotalPoints();
  }
}

/// 连续自律天数
class StreakNotifier extends StateNotifier<int> {
  StreakNotifier() : super(0) {
    _init();
  }

  Future<void> _init() async {
    try { await load(); } catch (_) {}
  }

  Future<void> load() async {
    state = await DatabaseHelper.getConsecutiveDisciplineDays();
  }
}

final achievementsProvider =
    StateNotifierProvider<AchievementsNotifier, List<Achievement>>(
        (ref) => AchievementsNotifier());

final pointsProvider =
    StateNotifierProvider<PointsNotifier, int>((ref) => PointsNotifier());

final streakProvider =
    StateNotifierProvider<StreakNotifier, int>((ref) => StreakNotifier());
