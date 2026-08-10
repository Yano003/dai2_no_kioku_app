import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/domain/card/day_card.dart';
import 'package:dai2_no_kioku/domain/parser/parsed_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// 通知時刻の既定値。就寝22:00 / 起床07:00 の30分前。（要件定義書 6.2）
const _morningNotify = ClockTime(6, 30);
const _nightNotify = ClockTime(21, 30);

ScheduleEntry _entry(DateTime date, {bool completed = false}) {
  return ScheduleEntry(
    schedule: Schedule(
      id: 'id-${completed ? 'done' : 'todo'}-${date.day}',
      title: 'テスト予定',
      baseDate: date,
      repeat: RepeatType.none,
      createdAt: DateTime(2026, 8, 1),
    ),
    date: date,
    isCompleted: completed,
  );
}

DayCard _card({
  required DateTime cardDate,
  required DateTime now,
  List<ScheduleEntry> entries = const [],
}) {
  return buildDayCard(
    date: cardDate,
    entries: entries,
    now: now,
    morningNotifyTime: _morningNotify,
    nightNotifyTime: _nightNotify,
  );
}

void main() {
  final today = DateTime(2026, 8, 4);
  final tomorrow = DateTime(2026, 8, 5);
  final yesterday = DateTime(2026, 8, 3);

  group('当日のカード', () {
    test('朝の通知時刻から正午までは「当日朝」', () {
      expect(
        _card(cardDate: today, now: DateTime(2026, 8, 4, 7, 0)).variant,
        CardVariant.morning,
      );
      expect(
        _card(cardDate: today, now: DateTime(2026, 8, 4, 11, 59)).variant,
        CardVariant.morning,
      );
    });

    test('正午から夜の通知時刻までは「当日日中」', () {
      expect(
        _card(cardDate: today, now: DateTime(2026, 8, 4, 12, 0)).variant,
        CardVariant.daytime,
      );
      expect(
        _card(cardDate: today, now: DateTime(2026, 8, 4, 21, 29)).variant,
        CardVariant.daytime,
      );
    });

    test('朝の通知時刻より前は「当日日中」と同じ扱い', () {
      expect(
        _card(cardDate: today, now: DateTime(2026, 8, 4, 3, 0)).variant,
        CardVariant.daytime,
      );
    });

    test('夜の通知時刻以降、全完了なら「当日夜（全完了）」', () {
      final card = _card(
        cardDate: today,
        now: DateTime(2026, 8, 4, 22, 0),
        entries: [_entry(today, completed: true)],
      );
      expect(card.variant, CardVariant.nightAllDone);
      expect(card.allCompleted, isTrue);
    });

    test('夜の通知時刻以降、やり残しがあれば「当日夜（やり残しあり）」', () {
      final card = _card(
        cardDate: today,
        now: DateTime(2026, 8, 4, 22, 0),
        entries: [
          _entry(today, completed: true),
          _entry(today),
        ],
      );
      expect(card.variant, CardVariant.nightRemaining);
      expect(card.remainingCount, 1);
      expect(card.completedCount, 1);
    });

    test('予定が0件の日は全完了扱いにしない', () {
      // 何も無い日を「すべてできました」と祝うのは体験として不自然。
      final card = _card(cardDate: today, now: DateTime(2026, 8, 4, 22, 0));
      expect(card.isEmpty, isTrue);
      expect(card.allCompleted, isFalse);
      expect(card.variant, CardVariant.nightRemaining);
    });
  });

  group('翌日のカード', () {
    test('夜の通知時刻以降は「前日夜」', () {
      expect(
        _card(cardDate: tomorrow, now: DateTime(2026, 8, 4, 21, 30)).variant,
        CardVariant.previousNight,
      );
    });

    test('夜の通知時刻より前は「未来」', () {
      expect(
        _card(cardDate: tomorrow, now: DateTime(2026, 8, 4, 13, 0)).variant,
        CardVariant.future,
      );
    });
  });

  group('その他の日付', () {
    test('明後日以降は「未来」', () {
      expect(
        _card(
          cardDate: DateTime(2026, 8, 6),
          now: DateTime(2026, 8, 4, 22, 0),
        ).variant,
        CardVariant.future,
      );
    });

    test('昨日以前は「過去」', () {
      expect(
        _card(cardDate: yesterday, now: DateTime(2026, 8, 4, 10, 0)).variant,
        CardVariant.past,
      );
    });
  });

  group('完了チェックの可否', () {
    test('未来の予定は前もってチェックできない', () {
      expect(
        _card(cardDate: tomorrow, now: DateTime(2026, 8, 4, 13, 0)).isCheckable,
        isFalse,
      );
      expect(
        _card(cardDate: tomorrow, now: DateTime(2026, 8, 4, 22, 0)).isCheckable,
        isFalse,
      );
    });

    test('当日と過去はチェックできる', () {
      expect(
        _card(cardDate: today, now: DateTime(2026, 8, 4, 13, 0)).isCheckable,
        isTrue,
      );
      expect(
        _card(cardDate: yesterday, now: DateTime(2026, 8, 4, 13, 0)).isCheckable,
        isTrue,
      );
    });
  });
}
