/// 每日使用记录模型
class DailyUsage {
  final int? id;
  final String date;         // YYYY-MM-DD
  final String packageName;
  final double usageMinutes;

  DailyUsage({
    this.id,
    required this.date,
    required this.packageName,
    required this.usageMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'package_name': packageName,
      'usage_minutes': usageMinutes,
    };
  }

  factory DailyUsage.fromMap(Map<String, dynamic> map) {
    return DailyUsage(
      id: map['id'] as int?,
      date: map['date'] as String,
      packageName: map['package_name'] as String,
      usageMinutes: (map['usage_minutes'] as num).toDouble(),
    );
  }

  DailyUsage copyWith({
    int? id,
    String? date,
    String? packageName,
    double? usageMinutes,
  }) {
    return DailyUsage(
      id: id ?? this.id,
      date: date ?? this.date,
      packageName: packageName ?? this.packageName,
      usageMinutes: usageMinutes ?? this.usageMinutes,
    );
  }
}

/// 带应用名称的使用记录（用于 UI 展示）
class DailyUsageWithApp extends DailyUsage {
  final String appName;
  final String? categoryName;

  DailyUsageWithApp({
    super.id,
    required super.date,
    required super.packageName,
    required super.usageMinutes,
    required this.appName,
    this.categoryName,
  });
}

/// 带时段使用记录（用于时段持久化）
class DailyUsageWithPeriods extends DailyUsage {
  final double morningMinutes;
  final double afternoonMinutes;
  final double eveningMinutes;

  DailyUsageWithPeriods({
    super.id,
    required super.date,
    required super.packageName,
    required super.usageMinutes,
    required this.morningMinutes,
    required this.afternoonMinutes,
    required this.eveningMinutes,
  });

  factory DailyUsageWithPeriods.fromMap(Map<String, dynamic> map) {
    return DailyUsageWithPeriods(
      id: map['id'] as int?,
      date: map['date'] as String,
      packageName: map['package_name'] as String,
      usageMinutes: (map['usage_minutes'] as num).toDouble(),
      morningMinutes: ((map['morning_minutes'] as num?) ?? 0).toDouble(),
      afternoonMinutes: ((map['afternoon_minutes'] as num?) ?? 0).toDouble(),
      eveningMinutes: ((map['evening_minutes'] as num?) ?? 0).toDouble(),
    );
  }
}
