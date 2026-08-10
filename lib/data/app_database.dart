import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 端末内データベース。
///
/// すべてのデータは端末内にのみ保存し、サーバーは使用しない。
/// （要件定義書 7.1 / 10章 前提1）
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'dai2_no_kioku.db';
  static const _version = 1;

  Database? _database;

  Future<Database> get database async =>
      _database ??= await _open();

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    return openDatabase(
      p.join(directory, _fileName),
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE schedules (
            id             TEXT PRIMARY KEY,
            title          TEXT NOT NULL,
            base_date      TEXT NOT NULL,
            time_minutes   INTEGER,
            repeat_type    TEXT NOT NULL,
            repeat_weekday INTEGER,
            created_at     TEXT NOT NULL,
            deleted_at     TEXT
          )
        ''');

        // 予定 × 日付 の完了状態。繰り返し予定の完了は日付ごとに独立する。
        await db.execute('''
          CREATE TABLE occurrences (
            schedule_id  TEXT NOT NULL,
            date         TEXT NOT NULL,
            completed_at TEXT,
            PRIMARY KEY (schedule_id, date),
            FOREIGN KEY (schedule_id) REFERENCES schedules (id) ON DELETE CASCADE
          )
        ''');

        // 「確認しました」「おやすみなさい」等、カード単位の状態。
        await db.execute('''
          CREATE TABLE card_states (
            date            TEXT PRIMARY KEY,
            acknowledged_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_schedules_base_date ON schedules (base_date)',
        );
        await db.execute(
          'CREATE INDEX idx_occurrences_date ON occurrences (date)',
        );
      },
    );
  }

  /// テスト用。開いているデータベースを閉じる。
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
