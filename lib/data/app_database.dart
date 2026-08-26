import 'dart:io';

import 'package:flutter/services.dart';
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

  /// iOS の iCloud バックアップから DB ファイルを除外するためのチャンネル。
  ///
  /// sqflite にはこの機能が無いため、AppDelegate.swift 側でファイル属性を
  /// 立ててもらう。Android は allowBackup="false"（AndroidManifest.xml）で
  /// アプリのデータ全体がバックアップ対象外になるため、ここでの対応は不要。
  /// （弁護士レビュー 2026/08/26 対応）
  static const _backupExclusionChannel =
      MethodChannel('jp.co.hitokoto.kiokuwo/backup_exclusion');

  Database? _database;

  Future<Database> get database async =>
      _database ??= await _open();

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final path = p.join(directory, _fileName);
    final db = await openDatabase(
      path,
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

    await _excludeFromBackup(path);
    return db;
  }

  /// iOS でのみ、DB ファイルを iCloud バックアップの対象から除外する。
  ///
  /// ベストエフォート。プラットフォームチャンネルが無い環境（ウィジェット
  /// テスト等）や失敗時でもアプリの動作は妨げない。
  Future<void> _excludeFromBackup(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _backupExclusionChannel.invokeMethod<void>('exclude', {
        'path': path,
      });
    } catch (_) {
      // 失敗してもデータベース自体は使えるため、ここでは無視する。
    }
  }

  /// テスト用。開いているデータベースを閉じる。
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
