import 'package:sqflite/sqflite.dart';

/// SQLite 建表 SQL
class DatabaseMigrations {
  static const int dbVersion = 2;

  static const String createCategoriesTable = '''
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon_name TEXT DEFAULT 'folder',
      daily_limit_minutes INTEGER,
      color_hex TEXT DEFAULT '#6366F1',
      is_active INTEGER DEFAULT 1
    )
  ''';

  static const String createAppLimitsTable = '''
    CREATE TABLE IF NOT EXISTS app_limits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      package_name TEXT NOT NULL UNIQUE,
      app_name TEXT NOT NULL,
      category_id INTEGER,
      daily_limit_minutes INTEGER NOT NULL,
      morning_limit_minutes INTEGER,
      afternoon_limit_minutes INTEGER,
      evening_limit_minutes INTEGER,
      is_active INTEGER DEFAULT 1,
      overtime_interval_minutes INTEGER DEFAULT 5,
      created_at TEXT DEFAULT (datetime('now','localtime')),
      updated_at TEXT DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
    )
  ''';

  static const String createDailyUsageTable = '''
    CREATE TABLE IF NOT EXISTS daily_usage (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      package_name TEXT NOT NULL,
      usage_minutes REAL NOT NULL DEFAULT 0,
      morning_minutes REAL NOT NULL DEFAULT 0,
      afternoon_minutes REAL NOT NULL DEFAULT 0,
      evening_minutes REAL NOT NULL DEFAULT 0,
      UNIQUE(date, package_name)
    )
  ''';

  static const String createFocusConfigTable = '''
    CREATE TABLE IF NOT EXISTS focus_sessions_config (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL,
      blocked_packages TEXT DEFAULT '',
      blocked_categories TEXT DEFAULT '',
      strict_mode INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1
    )
  ''';

  static const String createFocusLogTable = '''
    CREATE TABLE IF NOT EXISTS focus_sessions_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      config_id INTEGER,
      config_name TEXT DEFAULT '专注',
      started_at TEXT NOT NULL,
      ended_at TEXT,
      completed INTEGER DEFAULT 0,
      duration_minutes REAL DEFAULT 0
    )
  ''';

  static const String createAchievementsTable = '''
    CREATE TABLE IF NOT EXISTS achievements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      badge_key TEXT NOT NULL UNIQUE,
      unlocked_at TEXT,
      is_unlocked INTEGER DEFAULT 0
    )
  ''';

  static const String createPointsLogTable = '''
    CREATE TABLE IF NOT EXISTS points_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      points INTEGER NOT NULL,
      reason TEXT,
      created_at TEXT DEFAULT (datetime('now','localtime'))
    )
  ''';

  static const String createDailyDisciplineTable = '''
    CREATE TABLE IF NOT EXISTS daily_discipline (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      all_limits_met INTEGER DEFAULT 0,
      total_screen_minutes REAL DEFAULT 0,
      focus_sessions_count INTEGER DEFAULT 0,
      focus_total_minutes REAL DEFAULT 0
    )
  ''';

  // 索引
  static const String createDailyUsageIndex = '''
    CREATE INDEX IF NOT EXISTS idx_daily_usage_date 
    ON daily_usage(date)
  ''';

  static const String createDailyDisciplineIndex = '''
    CREATE INDEX IF NOT EXISTS idx_daily_discipline_date 
    ON daily_discipline(date)
  ''';

  static const String createDailyUsageCompositeIndex = '''
    CREATE INDEX IF NOT EXISTS idx_daily_usage_date_package 
    ON daily_usage(date, package_name)
  ''';

  static const String createDailyDisciplineMetIndex = '''
    CREATE INDEX IF NOT EXISTS idx_daily_discipline_met_date 
    ON daily_discipline(all_limits_met, date DESC)
  ''';

  /// 增量迁移入口
  static Future<void> upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: 添加复合索引 + 时段列
      await db.execute(createDailyUsageCompositeIndex);
      await db.execute(createDailyDisciplineMetIndex);
      await db.execute("ALTER TABLE daily_usage ADD COLUMN morning_minutes REAL NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE daily_usage ADD COLUMN afternoon_minutes REAL NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE daily_usage ADD COLUMN evening_minutes REAL NOT NULL DEFAULT 0");
    }
  }
}
