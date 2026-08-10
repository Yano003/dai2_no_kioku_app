import '../../core/app_config.dart';
import '../../core/date_key.dart';
import '../../domain/parser/parsed_schedule.dart';

/// 登録済みの予定1件。（要件定義書 7.2）
///
/// 完了状態はこのクラスに持たせない。繰り返し予定は1件の定義に対して
/// 複数の日付で発生し、完了状態は日付ごとに存在するため、
/// [Occurrence] 側（occurrences テーブル）で保持する。
class Schedule {
  const Schedule({
    required this.id,
    required this.title,
    required this.baseDate,
    required this.repeat,
    required this.createdAt,
    this.time,
    this.weekday,
    this.deletedAt,
  });

  /// 予定の識別子。
  final String id;

  /// 予定名。（要件定義書 7.2「話した内容から抽出した用件」）
  final String title;

  /// 対象日。繰り返しの場合は基準日。（要件定義書 7.2）
  final DateTime baseDate;

  /// 時刻。null なら終日扱い。（要件定義書 7.2）
  final ClockTime? time;

  /// 繰り返し種別。
  final RepeatType repeat;

  /// 毎週の場合の曜日。DateTime.monday(1)〜DateTime.sunday(7)。
  final int? weekday;

  /// 登録日時。
  final DateTime createdAt;

  /// 削除日時。論理削除とし、過去のカードからは消さない。
  ///
  /// 「カードは完了後も削除せず蓄積し、履歴として閲覧できる」（要件定義書 7.2）
  /// を満たすため、物理削除すると過去の履歴まで書き換わってしまう。
  final DateTime? deletedAt;

  /// この予定が [date] に発生するか。
  ///
  /// 削除済みの予定は削除日以降には現れないが、削除日より前のカードには
  /// 履歴としてそのまま残る。
  bool occursOn(DateTime date) {
    final target = dateOnly(date);

    if (deletedAt != null && !target.isBefore(dateOnly(deletedAt!))) {
      return false;
    }
    if (target.isBefore(baseDate)) return false;

    switch (repeat) {
      case RepeatType.none:
        return isSameDate(baseDate, target);
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        return target.weekday == weekday;
    }
  }

  Schedule copyWith({
    String? title,
    DateTime? baseDate,
    ClockTime? time,
    bool clearTime = false,
    RepeatType? repeat,
    int? weekday,
    DateTime? deletedAt,
  }) {
    return Schedule(
      id: id,
      title: title ?? this.title,
      baseDate: baseDate ?? this.baseDate,
      time: clearTime ? null : (time ?? this.time),
      repeat: repeat ?? this.repeat,
      weekday: weekday ?? this.weekday,
      createdAt: createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'base_date': toDateKey(baseDate),
        'time_minutes': time?.totalMinutes,
        'repeat_type': repeat.name,
        'repeat_weekday': weekday,
        'created_at': createdAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  factory Schedule.fromMap(Map<String, Object?> map) {
    final minutes = map['time_minutes'] as int?;
    return Schedule(
      id: map['id']! as String,
      title: map['title']! as String,
      baseDate: fromDateKey(map['base_date']! as String),
      time: minutes == null ? null : ClockTime(minutes ~/ 60, minutes % 60),
      repeat: RepeatType.values.byName(map['repeat_type']! as String),
      weekday: map['repeat_weekday'] as int?,
      createdAt: DateTime.parse(map['created_at']! as String),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at']! as String),
    );
  }
}

/// 予定 × 日付 の状態。完了チェックを保持する。（要件定義書 4.5 / 2.1 ⑥）
///
/// 繰り返し予定は「その日のカードでチェックしても、翌日には未完了の状態で
/// 再び現れる」（要件定義書 5章 確認事項）という仕様のため、
/// 完了状態は必ず日付とセットで持つ必要がある。
class Occurrence {
  const Occurrence({
    required this.scheduleId,
    required this.date,
    this.completedAt,
  });

  final String scheduleId;
  final DateTime date;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  Map<String, Object?> toMap() => {
        'schedule_id': scheduleId,
        'date': toDateKey(date),
        'completed_at': completedAt?.toIso8601String(),
      };

  factory Occurrence.fromMap(Map<String, Object?> map) => Occurrence(
        scheduleId: map['schedule_id']! as String,
        date: fromDateKey(map['date']! as String),
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.parse(map['completed_at']! as String),
      );
}

/// カード上の1行。予定の定義と、その日の完了状態を組にしたもの。
class ScheduleEntry {
  const ScheduleEntry({
    required this.schedule,
    required this.date,
    required this.isCompleted,
  });

  final Schedule schedule;
  final DateTime date;
  final bool isCompleted;

  String get id => schedule.id;
  String get title => schedule.title;
  ClockTime? get time => schedule.time;
  bool get isRepeating => schedule.repeat != RepeatType.none;
}
