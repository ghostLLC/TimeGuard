import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_limit.dart';
import '../models/category.dart';
import '../models/daily_usage.dart';
import '../models/focus_session.dart';
import '../models/achievement.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import 'migrations.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'timeguard.db';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: DatabaseMigrations.dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute(DatabaseMigrations.createCategoriesTable);
    batch.execute(DatabaseMigrations.createAppLimitsTable);
    batch.execute(DatabaseMigrations.createDailyUsageTable);
    batch.execute(DatabaseMigrations.createFocusConfigTable);
    batch.execute(DatabaseMigrations.createFocusLogTable);
    batch.execute(DatabaseMigrations.createAchievementsTable);
    batch.execute(DatabaseMigrations.createPointsLogTable);
    batch.execute(DatabaseMigrations.createDailyDisciplineTable);
    batch.execute(DatabaseMigrations.createDailyUsageIndex);
    batch.execute(DatabaseMigrations.createDailyDisciplineIndex);
    await batch.commit(noResult: true);

    // 插入默认分类
    for (final cat in AppConstants.defaultCategories) {
      await db.insert('categories', cat);
    }

    // 插入成就记录
    for (final achievement in AchievementCatalog.all) {
      await db.insert('achievements', achievement.toMap());
    }
  }

  // ════════════════════════════════════════════
  // ── App Limits CRUD ──
  // ════════════════════════════════════════════

  static Future<List<AppLimit>> getAppLimits() async {
    final db = await database;
    final maps = await db.query(
      'app_limits',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'app_name ASC',
    );
    return maps.map((m) => AppLimit.fromMap(m)).toList();
  }

  static Future<AppLimit?> getAppLimitByPackage(String packageName) async {
    final db = await database;
    final maps = await db.query(
      'app_limits',
      where: 'package_name = ? AND is_active = ?',
      whereArgs: [packageName, 1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppLimit.fromMap(maps.first);
  }

  static Future<int> insertAppLimit(AppLimit limit) async {
    final db = await database;
    return await db.insert('app_limits', limit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> updateAppLimit(AppLimit limit) async {
    final db = await database;
    return await db.update(
      'app_limits',
      limit.toMap(),
      where: 'id = ?',
      whereArgs: [limit.id],
    );
  }

  static Future<int> deleteAppLimit(int id) async {
    final db = await database;
    return await db.update(
      'app_limits',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ════════════════════════════════════════════
  // ── Categories CRUD ──
  // ════════════════════════════════════════════

  static Future<List<AppCategory>> getCategories() async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((m) => AppCategory.fromMap(m)).toList();
  }

  static Future<AppCategory?> getCategoryById(int id) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppCategory.fromMap(maps.first);
  }

  static Future<AppCategory?> getCategoryByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppCategory.fromMap(maps.first);
  }

  static Future<int> insertCategory(AppCategory category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  static Future<int> updateCategory(AppCategory category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // ════════════════════════════════════════════
  // ── Daily Usage CRUD ──
  // ════════════════════════════════════════════

  static Future<List<DailyUsage>> getDailyUsage(String date) async {
    final db = await database;
    final maps = await db.query(
      'daily_usage',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'usage_minutes DESC',
    );
    return maps.map((m) => DailyUsage.fromMap(m)).toList();
  }

  static Future<double> getAppUsageToday(String packageName) async {
    final db = await database;
    final today = AppUtils.todayString();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(usage_minutes), 0) as total 
      FROM daily_usage 
      WHERE date = ? AND package_name = ?
    ''', [today, packageName]);
    return (result.first['total'] as num).toDouble();
  }

  static Future<Map<String, double>> getUsageByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT package_name, SUM(usage_minutes) as total 
      FROM daily_usage 
      WHERE date BETWEEN ? AND ?
      GROUP BY package_name
      ORDER BY total DESC
    ''', [startDate, endDate]);
    return {
      for (final row in result)
        row['package_name'] as String:
            (row['total'] as num).toDouble(),
    };
  }

  static Future<List<Map<String, dynamic>>> getDailyTotalUsage(
      int days) async {
    final db = await database;
    final dates = AppUtils.pastDays(days);
    final result = await db.rawQuery('''
      SELECT date, SUM(usage_minutes) as total 
      FROM daily_usage 
      WHERE date IN (${dates.map((_) => '?').join(',')})
      GROUP BY date
      ORDER BY date ASC
    ''', dates);
    return result;
  }

  static Future<void> upsertDailyUsage(
      String date, String packageName, double minutes) async {
    final db = await database;
    await db.insert(
      'daily_usage',
      {
        'date': date,
        'package_name': packageName,
        'usage_minutes': minutes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ════════════════════════════════════════════
  // ── Focus Session CRUD ──
  // ════════════════════════════════════════════

  static Future<List<FocusSessionConfig>> getFocusConfigs() async {
    final db = await database;
    final maps = await db.query(
      'focus_sessions_config',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    return maps.map((m) => FocusSessionConfig.fromMap(m)).toList();
  }

  static Future<int> insertFocusConfig(FocusSessionConfig config) async {
    final db = await database;
    return await db.insert('focus_sessions_config', config.toMap());
  }

  static Future<int> insertFocusLog(FocusSessionLog log) async {
    final db = await database;
    return await db.insert('focus_sessions_log', log.toMap());
  }

  static Future<List<FocusSessionLog>> getFocusLogs({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'focus_sessions_log',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return maps.map((m) => FocusSessionLog.fromMap(m)).toList();
  }

  static Future<double> getTotalFocusMinutes() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(duration_minutes), 0) as total 
      FROM focus_sessions_log 
      WHERE completed = 1
    ''');
    return (result.first['total'] as num).toDouble();
  }

  // ════════════════════════════════════════════
  // ── Achievements ──
  // ════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAchievements() async {
    final db = await database;
    return await db.query('achievements');
  }

  static Future<void> unlockAchievement(String key) async {
    final db = await database;
    await db.update(
      'achievements',
      {
        'is_unlocked': 1,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      where: 'badge_key = ?',
      whereArgs: [key],
    );
  }

  static Future<bool> isAchievementUnlocked(String key) async {
    final db = await database;
    final result = await db.query(
      'achievements',
      where: 'badge_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return false;
    return (result.first['is_unlocked'] as int) == 1;
  }

  // ════════════════════════════════════════════
  // ── Points ──
  // ════════════════════════════════════════════

  static Future<int> getTotalPoints() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(points), 0) as total FROM points_log');
    return (result.first['total'] as num).toInt();
  }

  static Future<void> addPoints(int points, String reason) async {
    final db = await database;
    await db.insert('points_log', {
      'points': points,
      'reason': reason,
    });
  }

  // ════════════════════════════════════════════
  // ── Daily Discipline ──
  // ════════════════════════════════════════════

  static Future<DailyDiscipline?> getDailyDiscipline(String date) async {
    final db = await database;
    final maps = await db.query(
      'daily_discipline',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyDiscipline.fromMap(maps.first);
  }

  static Future<void> upsertDailyDiscipline(DailyDiscipline dd) async {
    final db = await database;
    await db.insert(
      'daily_discipline',
      dd.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> getConsecutiveDisciplineDays() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT date FROM daily_discipline 
      WHERE all_limits_met = 1 
      ORDER BY date DESC
    ''');
    if (result.isEmpty) return 0;

    int streak = 0;
    DateTime expected = DateTime.now();
    for (final row in result) {
      final date = DateTime.parse(row['date'] as String);
      final diff = expected.difference(date).inDays;
      if (diff == 0 || (diff == 1 && streak == 0)) {
        streak++;
        expected = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
