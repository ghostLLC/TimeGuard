import 'package:flutter/material.dart';

/// 应用分类模型
class AppCategory {
  final int? id;
  final String name;
  final String iconName;
  final int? dailyLimitMinutes; // 分类总限额（可选）
  final Color color;
  final bool isActive;

  AppCategory({
    this.id,
    required this.name,
    this.iconName = 'folder',
    this.dailyLimitMinutes,
    this.color = const Color(0xFF6366F1),
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon_name': iconName,
      'daily_limit_minutes': dailyLimitMinutes,
      'color_hex': '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      'is_active': isActive ? 1 : 0,
    };
  }

  factory AppCategory.fromMap(Map<String, dynamic> map) {
    final colorHex = map['color_hex'] as String? ?? '#6366F1';
    return AppCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconName: map['icon_name'] as String? ?? 'folder',
      dailyLimitMinutes: map['daily_limit_minutes'] as int?,
      color: Color(int.tryParse(colorHex.replaceFirst('#', 'FF'), radix: 16) ?? 0xFF6366F1),
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  AppCategory copyWith({
    int? id,
    String? name,
    String? iconName,
    int? dailyLimitMinutes,
    Color? color,
    bool? isActive,
  }) {
    return AppCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
    );
  }
}
