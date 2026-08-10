import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// 繰り返し予定が、どの日付のカードに現れるかの判定。
///
/// 要件定義書 7.2 のデータ項目では、1件の予定に対して完了状態が1つしか
/// 持てず、繰り返し予定の日ごとの完了を表現できない。本実装では予定の定義と
/// 日付ごとの発生を分離しており、その発生判定をここで固定する。
Schedule _schedule({
  required DateTime baseDate,
  RepeatType repeat = RepeatType.none,
  int? weekday,
  DateTime? deletedAt,
}) {
  return Schedule(
    id: 'test-id',
    title: 'テスト予定',
    baseDate: baseDate,
    repeat: repeat,
    weekday: weekday,
    createdAt: DateTime(2026, 8, 1),
    deletedAt: deletedAt,
  );
}

void main() {
  group('繰り返しなし', () {
    final schedule = _schedule(baseDate: DateTime(2026, 8, 10));

    test('基準日にだけ現れる', () {
      expect(schedule.occursOn(DateTime(2026, 8, 10)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 8, 9)), isFalse);
      expect(schedule.occursOn(DateTime(2026, 8, 11)), isFalse);
    });

    test('時刻成分があっても同じ日なら現れる', () {
      expect(schedule.occursOn(DateTime(2026, 8, 10, 23, 59)), isTrue);
    });
  });

  group('毎日', () {
    final schedule = _schedule(
      baseDate: DateTime(2026, 8, 10),
      repeat: RepeatType.daily,
    );

    test('基準日以降は毎日現れる', () {
      expect(schedule.occursOn(DateTime(2026, 8, 10)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 8, 11)), isTrue);
      expect(schedule.occursOn(DateTime(2027, 3, 1)), isTrue);
    });

    test('基準日より前には現れない', () {
      expect(schedule.occursOn(DateTime(2026, 8, 9)), isFalse);
    });
  });

  group('毎週', () {
    // 2026年8月5日は水曜日。
    final schedule = _schedule(
      baseDate: DateTime(2026, 8, 5),
      repeat: RepeatType.weekly,
      weekday: DateTime.wednesday,
    );

    test('該当曜日にだけ現れる', () {
      expect(schedule.occursOn(DateTime(2026, 8, 5)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 8, 12)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 8, 19)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 8, 6)), isFalse);
    });

    test('基準日より前の同じ曜日には現れない', () {
      expect(schedule.occursOn(DateTime(2026, 7, 29)), isFalse);
    });
  });

  group('論理削除', () {
    // 削除しても過去のカードからは消さない。（要件定義書 7.2 履歴の保持）
    final schedule = _schedule(
      baseDate: DateTime(2026, 8, 1),
      repeat: RepeatType.daily,
      deletedAt: DateTime(2026, 8, 10, 14, 30),
    );

    test('削除日以降には現れない', () {
      expect(schedule.occursOn(DateTime(2026, 8, 10)), isFalse);
      expect(schedule.occursOn(DateTime(2026, 8, 11)), isFalse);
    });

    test('削除日より前の履歴には残る', () {
      expect(schedule.occursOn(DateTime(2026, 8, 9)), isTrue);
      expect(schedule.occursOn(DateTime(2026, 8, 1)), isTrue);
    });
  });
}
