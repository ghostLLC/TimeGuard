import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_limit.dart';
import '../models/category.dart';
import '../database/database_helper.dart';

/// 应用限额状态管理
class AppLimitsNotifier extends StateNotifier<List<AppLimit>> {
  AppLimitsNotifier() : super([]) {
    load();
  }

  Future<void> load() async {
    state = await DatabaseHelper.getAppLimits();
  }

  Future<void> addLimit(AppLimit limit) async {
    await DatabaseHelper.insertAppLimit(limit);
    await load();
  }

  Future<void> updateLimit(AppLimit limit) async {
    await DatabaseHelper.updateAppLimit(limit);
    await load();
  }

  Future<void> removeLimit(int id) async {
    await DatabaseHelper.deleteAppLimit(id);
    await load();
  }

  AppLimit? findByPackage(String packageName) {
    try {
      return state.firstWhere((l) => l.packageName == packageName);
    } catch (_) {
      return null;
    }
  }
}

/// 分类状态管理
class CategoriesNotifier extends StateNotifier<List<AppCategory>> {
  CategoriesNotifier() : super([]) {
    load();
  }

  Future<void> load() async {
    state = await DatabaseHelper.getCategories();
  }

  Future<void> addCategory(AppCategory category) async {
    await DatabaseHelper.insertCategory(category);
    await load();
  }

  Future<void> updateCategory(AppCategory category) async {
    await DatabaseHelper.updateCategory(category);
    await load();
  }

  AppCategory? findById(int id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  AppCategory? findByName(String name) {
    try {
      return state.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }
}

final appLimitsProvider =
    StateNotifierProvider<AppLimitsNotifier, List<AppLimit>>(
        (ref) => AppLimitsNotifier());

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<AppCategory>>(
        (ref) => CategoriesNotifier());
