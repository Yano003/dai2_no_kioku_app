import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/app_config.dart';
import '../core/date_key.dart';
import '../domain/parser/parsed_schedule.dart';
import 'app_database.dart';
import 'models/schedule.dart';

/// 予定の永続化と取り出しを担う。
///
/// 繰り返し予定は「定義1件」としてのみ保存し、日付ごとの行は作らない。
/// 特定日の予定一覧は、定義の一覧を [Schedule.occursOn] で絞り込んで組み立てる。
/// 完了状態のある日付だけ occurrences に行が作られる。
class ScheduleRepository {
  ScheduleRepository({AppDatabase? db, Uuid? uuid})
      : _db = db ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<Database> get _database => _db.database;

  // ---------------------------------------------------------------------------
  // 登録
  // ---------------------------------------------------------------------------

  /// 解析結果を予定として登録する。
  ///
  /// [ParsedSchedule.date] が null の場合は登録できない。S-03（登録確認画面）で
  /// 日付を必ず確定させてから呼ぶこと。
  Future<Schedule> insertParsed(ParsedSchedule parsed) {
    final date = parsed.date;
    if (date == null) {
      throw ArgumentError('日付が未確定の予定は登録できません: ${parsed.title}');
    }
    return insert(
      title: parsed.title,
      baseDate: date,
      time: parsed.time,
      repeat: parsed.repeat,
      weekday: parsed.weekday,
    );
  }

  Future<Schedule> insert({
    required String title,
    required DateTime baseDate,
    ClockTime? time,
    RepeatType repeat = RepeatType.none,
    int? weekday,
  }) async {
    final schedule = Schedule(
      id: _uuid.v4(),
      title: title,
      baseDate: dateOnly(baseDate),
      time: time,
      repeat: repeat,
      weekday: weekday,
      createdAt: DateTime.now(),
    );

    final db = await _database;
    await db.insert('schedules', schedule.toMap());
    return schedule;
  }

  // ---------------------------------------------------------------------------
  // 取り出し
  // ---------------------------------------------------------------------------

  /// 削除されていない予定の定義をすべて返す。
  Future<List<Schedule>> activeSchedules() async {
    final db = await _database;
    final rows = await db.query(
      'schedules',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at',
    );
    return rows.map(Schedule.fromMap).toList(growable: false);
  }

  /// 論理削除済みを含むすべての予定の定義を返す。過去のカードの再現に使う。
  Future<List<Schedule>> allSchedules() async {
    final db = await _database;
    final rows = await db.query('schedules', orderBy: 'created_at');
    return rows.map(Schedule.fromMap).toList(growable: false);
  }

  /// 指定日の予定一覧を、完了状態つきで返す。
  Future<List<ScheduleEntry>> entriesForDate(DateTime date) async {
    final entries = await entriesForRange(date, date);
    return entries[dateOnly(date)] ?? const [];
  }

  /// 指定期間の日付ごとの予定一覧を、完了状態つきで返す。
  ///
  /// カード画面のスクロール表示・カレンダーの印・通知の件数計算で共通に使う。
  Future<Map<DateTime, List<ScheduleEntry>>> entriesForRange(
    DateTime from,
    DateTime to,
  ) async {
    final schedules = await allSchedules();
    final completed = await _completedKeys(from, to);
    final result = <DateTime, List<ScheduleEntry>>{};

    for (final date in dateRange(from, to)) {
      final entries = <ScheduleEntry>[];
      for (final schedule in schedules) {
        if (!schedule.occursOn(date)) continue;
        entries.add(
          ScheduleEntry(
            schedule: schedule,
            date: date,
            isCompleted: completed.contains('${schedule.id}|${toDateKey(date)}'),
          ),
        );
      }
      entries.sort(_byTimeThenCreatedAt);
      result[date] = entries;
    }

    return result;
  }

  /// 時刻指定のある予定を先に、時刻順で並べる。終日はその後ろ。
  static int _byTimeThenCreatedAt(ScheduleEntry a, ScheduleEntry b) {
    final timeA = a.time;
    final timeB = b.time;
    if (timeA != null && timeB != null) {
      final compared = timeA.compareTo(timeB);
      if (compared != 0) return compared;
    } else if (timeA != null) {
      return -1;
    } else if (timeB != null) {
      return 1;
    }
    return a.schedule.createdAt.compareTo(b.schedule.createdAt);
  }

  Future<Set<String>> _completedKeys(DateTime from, DateTime to) async {
    final db = await _database;
    final rows = await db.query(
      'occurrences',
      columns: ['schedule_id', 'date'],
      where: 'completed_at IS NOT NULL AND date >= ? AND date <= ?',
      whereArgs: [toDateKey(from), toDateKey(to)],
    );
    return rows
        .map((row) => '${row['schedule_id']}|${row['date']}')
        .toSet();
  }

  /// 指定期間の日付ごとの予定件数。カレンダーの印と通知文の件数に使う。
  Future<Map<DateTime, int>> countsForRange(DateTime from, DateTime to) async {
    final entries = await entriesForRange(from, to);
    return entries.map((date, list) => MapEntry(date, list.length));
  }

  // ---------------------------------------------------------------------------
  // 1日あたりの上限（要件定義書 2.2）
  // ---------------------------------------------------------------------------

  /// 指定日にあと何件登録できるか。上限に達していれば 0。
  ///
  /// 繰り返し予定もその日に発生する分として数える。件数の算出は
  /// カレンダーの印や通知文と同じ [entriesForRange] を通すため、
  /// 画面に見えている件数と必ず一致する。
  Future<int> remainingCapacityOn(DateTime date) async {
    final entries = await entriesForDate(date);
    final remaining = AppConfig.maxSchedulesPerDay - entries.length;
    return remaining < 0 ? 0 : remaining;
  }

  /// 指定日ごとの残り登録可能件数をまとめて返す。
  ///
  /// 複数の予定をまとめて発話した場合（要件定義書 4.3）、同じ日に何件
  /// 追加しようとしているかを含めて判定する必要があるため、日付単位で返す。
  Future<Map<DateTime, int>> remainingCapacityForDates(
    Iterable<DateTime> dates,
  ) async {
    final normalized = dates.map(dateOnly).toSet();
    if (normalized.isEmpty) return {};

    final sorted = normalized.toList()..sort();
    final entries = await entriesForRange(sorted.first, sorted.last);

    return {
      for (final date in normalized)
        date: () {
          final used = entries[date]?.length ?? 0;
          final remaining = AppConfig.maxSchedulesPerDay - used;
          return remaining < 0 ? 0 : remaining;
        }(),
    };
  }

  // ---------------------------------------------------------------------------
  // 完了チェック
  // ---------------------------------------------------------------------------

  /// 指定日の完了状態を設定する。（要件定義書 4.5）
  Future<void> setCompleted({
    required String scheduleId,
    required DateTime date,
    required bool completed,
  }) async {
    final db = await _database;
    await db.insert(
      'occurrences',
      Occurrence(
        scheduleId: scheduleId,
        date: dateOnly(date),
        completedAt: completed ? DateTime.now() : null,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // 修正・削除（S-07）
  // ---------------------------------------------------------------------------

  /// 予定を更新する。
  ///
  /// 繰り返し予定の場合、[AppConfig.repeatEditScope] に従い今後すべての回へ
  /// 適用する。「この日だけ」の変更は MVP では扱わない。
  Future<void> update(Schedule schedule) async {
    final db = await _database;
    await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  /// 予定を削除する。
  ///
  /// 物理削除ではなく削除日時を記録する。過去のカードは履歴として
  /// 閲覧できる必要があるため（要件定義書 7.2）、削除日より前の日付では
  /// この予定は引き続き表示される。
  Future<void> delete(String scheduleId) async {
    final db = await _database;
    await db.update(
      'schedules',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<Schedule?> findById(String scheduleId) async {
    final db = await _database;
    final rows = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
      limit: 1,
    );
    return rows.isEmpty ? null : Schedule.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------------
  // カード単位の状態
  // ---------------------------------------------------------------------------

  /// 「確認しました」を押した日付を記録する。（確認事項 No.4）
  Future<void> acknowledgeCard(DateTime date) async {
    final db = await _database;
    await db.insert(
      'card_states',
      {
        'date': toDateKey(date),
        'acknowledged_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<DateTime>> acknowledgedDates(DateTime from, DateTime to) async {
    final db = await _database;
    final rows = await db.query(
      'card_states',
      columns: ['date'],
      where: 'acknowledged_at IS NOT NULL AND date >= ? AND date <= ?',
      whereArgs: [toDateKey(from), toDateKey(to)],
    );
    return rows.map((row) => fromDateKey(row['date']! as String)).toSet();
  }
}
