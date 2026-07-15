import '../core/constants.dart';

/// 应用限额模型
class AppLimit {
  final int? id;
  final String packageName;
  final String appName;
  final int? categoryId;
  final int dailyLimitMinutes;
  final int? morningLimitMinutes;   // 上午限额（可选）
  final int? afternoonLimitMinutes; // 下午限额（可选）
  final int? eveningLimitMinutes;   // 晚上限额（可选）
  final bool isActive;
  final int overtimeIntervalMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppLimit({
    this.id,
    required this.packageName,
    required this.appName,
    this.categoryId,
    required this.dailyLimitMinutes,
    this.morningLimitMinutes,
    this.afternoonLimitMinutes,
    this.eveningLimitMinutes,
    this.isActive = true,
    this.overtimeIntervalMinutes = AppConstants.defaultOvertimeIntervalMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 获取指定时段的限额（分钟），如果未设置则返回 null
  int? getLimitForPeriod(TimePeriod period) {
    switch (period) {
      case TimePeriod.morning:
        return morningLimitMinutes;
      case TimePeriod.afternoon:
        return afternoonLimitMinutes;
      case TimePeriod.evening:
        return eveningLimitMinutes;
    }
  }

  /// 是否启用了时段限额
  bool get hasPeriodLimits =>
      morningLimitMinutes != null ||
      afternoonLimitMinutes != null ||
      eveningLimitMinutes != null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'app_name': appName,
      'category_id': categoryId,
      'daily_limit_minutes': dailyLimitMinutes,
      'morning_limit_minutes': morningLimitMinutes,
      'afternoon_limit_minutes': afternoonLimitMinutes,
      'evening_limit_minutes': eveningLimitMinutes,
      'is_active': isActive ? 1 : 0,
      'overtime_interval_minutes': overtimeIntervalMinutes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppLimit.fromMap(Map<String, dynamic> map) {
    return AppLimit(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String,
      categoryId: map['category_id'] as int?,
      dailyLimitMinutes: map['daily_limit_minutes'] as int,
      morningLimitMinutes: map['morning_limit_minutes'] as int?,
      afternoonLimitMinutes: map['afternoon_limit_minutes'] as int?,
      eveningLimitMinutes: map['evening_limit_minutes'] as int?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      overtimeIntervalMinutes:
          map['overtime_interval_minutes'] as int? ??
              AppConstants.defaultOvertimeIntervalMinutes,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  AppLimit copyWith({
    int? id,
    String? packageName,
    String? appName,
    int? categoryId,
    int? dailyLimitMinutes,
    int? morningLimitMinutes,
    int? afternoonLimitMinutes,
    int? eveningLimitMinutes,
    bool? isActive,
    int? overtimeIntervalMinutes,
  }) {
    return AppLimit(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      categoryId: categoryId ?? this.categoryId,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      morningLimitMinutes: morningLimitMinutes ?? this.morningLimitMinutes,
      afternoonLimitMinutes:
          afternoonLimitMinutes ?? this.afternoonLimitMinutes,
      eveningLimitMinutes: eveningLimitMinutes ?? this.eveningLimitMinutes,
      isActive: isActive ?? this.isActive,
      overtimeIntervalMinutes:
          overtimeIntervalMinutes ?? this.overtimeIntervalMinutes,
    );
  }
}
