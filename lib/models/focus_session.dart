/// 专注模式配置
class FocusSessionConfig {
  final int? id;
  final String name;
  final int durationMinutes;
  final List<String> blockedPackages;
  final List<int> blockedCategories;
  final bool strictMode;
  final bool isActive;

  FocusSessionConfig({
    this.id,
    required this.name,
    required this.durationMinutes,
    this.blockedPackages = const [],
    this.blockedCategories = const [],
    this.strictMode = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'duration_minutes': durationMinutes,
      'blocked_packages': blockedPackages.join(','),
      'blocked_categories': blockedCategories.join(','),
      'strict_mode': strictMode ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory FocusSessionConfig.fromMap(Map<String, dynamic> map) {
    return FocusSessionConfig(
      id: map['id'] as int?,
      name: map['name'] as String,
      durationMinutes: map['duration_minutes'] as int,
      blockedPackages: (map['blocked_packages'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      blockedCategories: (map['blocked_categories'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .map((s) => int.tryParse(s))
              .whereType<int>()
              .toList() ??
          [],
      strictMode: (map['strict_mode'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}

/// 专注模式运行状态
enum FocusStatus {
  idle,
  running,
  paused,
  completed,
  cancelled,
}

/// 专注模式当前状态
class FocusSessionState {
  final FocusStatus status;
  final FocusSessionConfig? config;
  final int remainingSeconds;
  final int totalSeconds;
  final DateTime? startedAt;

  const FocusSessionState({
    this.status = FocusStatus.idle,
    this.config,
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.startedAt,
  });

  double get progress =>
      totalSeconds > 0 ? (totalSeconds - remainingSeconds) / totalSeconds : 0;

  FocusSessionState copyWith({
    FocusStatus? status,
    FocusSessionConfig? config,
    int? remainingSeconds,
    int? totalSeconds,
    DateTime? startedAt,
  }) {
    return FocusSessionState(
      status: status ?? this.status,
      config: config ?? this.config,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

/// 专注历史记录
class FocusSessionLog {
  final int? id;
  final int? configId;
  final String configName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool completed;
  final double durationMinutes;

  FocusSessionLog({
    this.id,
    this.configId,
    required this.configName,
    required this.startedAt,
    this.endedAt,
    this.completed = false,
    required this.durationMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'config_id': configId,
      'config_name': configName,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'completed': completed ? 1 : 0,
      'duration_minutes': durationMinutes,
    };
  }

  factory FocusSessionLog.fromMap(Map<String, dynamic> map) {
    return FocusSessionLog(
      id: map['id'] as int?,
      configId: map['config_id'] as int?,
      configName: map['config_name'] as String? ?? '专注',
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      completed: (map['completed'] as int? ?? 0) == 1,
      durationMinutes: (map['duration_minutes'] as num?)?.toDouble() ?? 0,
    );
  }
}
