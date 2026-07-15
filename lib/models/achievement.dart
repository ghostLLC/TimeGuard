/// 成就徽章模型
class Achievement {
  final String key;
  final String name;
  final String description;
  final String iconName;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int? progress;      // 当前进度
  final int? targetProgress; // 目标值

  const Achievement({
    required this.key,
    required this.name,
    required this.description,
    required this.iconName,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress,
    this.targetProgress,
  });

  double get progressRatio {
    if (targetProgress == null || targetProgress == 0) return isUnlocked ? 1 : 0;
    return (progress ?? 0) / targetProgress!;
  }

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? progress,
    int? targetProgress,
  }) {
    return Achievement(
      key: key,
      name: name,
      description: description,
      iconName: iconName,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      targetProgress: targetProgress ?? this.targetProgress,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'badge_key': key,
      'is_unlocked': isUnlocked ? 1 : 0,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      key: map['badge_key'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconName: map['icon_name'] as String? ?? 'star',
      isUnlocked: (map['is_unlocked'] as int? ?? 0) == 1,
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.parse(map['unlocked_at'] as String)
          : null,
    );
  }
}

/// 所有预定义成就
class AchievementCatalog {
  static const List<Achievement> all = [
    Achievement(
      key: 'first_discipline_day',
      name: '初见成效',
      description: '达成首个自律日',
      iconName: 'eco',
      targetProgress: 1,
    ),
    Achievement(
      key: 'three_day_streak',
      name: '三日不辍',
      description: '连续 3 天自律日',
      iconName: 'local_florist',
      targetProgress: 3,
    ),
    Achievement(
      key: 'weekend_warrior',
      name: '周末战士',
      description: '连续 2 个周末全部达标',
      iconName: 'shield',
      targetProgress: 2,
    ),
    Achievement(
      key: 'week_streak',
      name: '周自律',
      description: '连续 7 天自律日',
      iconName: 'star',
      targetProgress: 7,
    ),
    Achievement(
      key: 'month_streak',
      name: '月度之星',
      description: '连续 30 天自律日',
      iconName: 'workspace_premium',
      targetProgress: 30,
    ),
    Achievement(
      key: 'focus_100h',
      name: '专注大师',
      description: '累计专注时长达 100 小时',
      iconName: 'self_improvement',
      targetProgress: 6000, // 6000 minutes = 100 hours
    ),
    Achievement(
      key: 'social_detox_7d',
      name: '社交戒断',
      description: '社交类应用连续 7 天未超时',
      iconName: 'chat_bubble_outline',
      targetProgress: 7,
    ),
    Achievement(
      key: 'quick_recovery',
      name: '回头是岸',
      description: '超时后 1 分钟内切走',
      iconName: 'signpost',
      targetProgress: 1,
    ),
  ];
}

/// 每日自律状态
class DailyDiscipline {
  final int? id;
  final String date;
  final bool allLimitsMet;
  final double totalScreenMinutes;
  final int focusSessionsCount;
  final double focusTotalMinutes;

  DailyDiscipline({
    this.id,
    required this.date,
    this.allLimitsMet = false,
    this.totalScreenMinutes = 0,
    this.focusSessionsCount = 0,
    this.focusTotalMinutes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'all_limits_met': allLimitsMet ? 1 : 0,
      'total_screen_minutes': totalScreenMinutes,
      'focus_sessions_count': focusSessionsCount,
      'focus_total_minutes': focusTotalMinutes,
    };
  }

  factory DailyDiscipline.fromMap(Map<String, dynamic> map) {
    return DailyDiscipline(
      id: map['id'] as int?,
      date: map['date'] as String,
      allLimitsMet: (map['all_limits_met'] as int? ?? 0) == 1,
      totalScreenMinutes:
          (map['total_screen_minutes'] as num?)?.toDouble() ?? 0,
      focusSessionsCount: map['focus_sessions_count'] as int? ?? 0,
      focusTotalMinutes:
          (map['focus_total_minutes'] as num?)?.toDouble() ?? 0,
    );
  }
}
