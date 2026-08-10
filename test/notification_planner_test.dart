import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/domain/parser/parsed_schedule.dart';
import 'package:dai2_no_kioku/services/notification_planner.dart';
import 'package:flutter_test/flutter_test.dart';

const _morningNotify = ClockTime(6, 30);
const _nightNotify = ClockTime(21, 30);

List<PlannedNotification> _plan({
  required DateTime now,
  Map<DateTime, int> counts = const {},
  int horizonDays = 14,
}) {
  return planNotifications(
    now: now,
    countsByDate: counts,
    morningNotifyTime: _morningNotify,
    nightNotifyTime: _nightNotify,
    horizonDays: horizonDays,
  );
}

void main() {
  group('予約する通知の組み立て', () {
    test('過去の時刻は予約しない', () {
      // 10時の時点では、その日の朝6:30の通知はもう予約できない。
      final planned = _plan(now: DateTime(2026, 8, 4, 10, 0), horizonDays: 0);

      expect(planned.every((n) => n.scheduledAt.isAfter(DateTime(2026, 8, 4, 10, 0))), isTrue);
      expect(
        planned.where((n) => n.kind == NotificationKind.morning),
        isEmpty,
      );
    });

    test('前日夜の通知は翌日のカードを開く', () {
      final planned = _plan(now: DateTime(2026, 8, 4, 10, 0), horizonDays: 0);
      final night = planned.firstWhere((n) => n.kind == NotificationKind.night);

      expect(night.scheduledAt, DateTime(2026, 8, 4, 21, 30));
      expect(night.cardDate, DateTime(2026, 8, 5));
      expect(night.payload, 'card:2026-08-05');
    });

    test('当日朝の通知はその日のカードを開き、件数を含む', () {
      final planned = _plan(
        now: DateTime(2026, 8, 4, 10, 0),
        counts: {DateTime(2026, 8, 5): 3},
        horizonDays: 1,
      );
      final morning = planned.firstWhere(
        (n) =>
            n.kind == NotificationKind.morning &&
            n.cardDate == DateTime(2026, 8, 5),
      );

      expect(morning.scheduledAt, DateTime(2026, 8, 5, 6, 30));
      // 通知の文面は予約時点で固定されるため、件数を事前に埋め込む必要がある。
      expect(morning.body, contains('3'));
    });

    test('予定が0件の日は別の文言になる', () {
      final planned = _plan(
        now: DateTime(2026, 8, 4, 10, 0),
        counts: const {},
        horizonDays: 1,
      );
      final morning = planned.firstWhere(
        (n) =>
            n.kind == NotificationKind.morning &&
            n.cardDate == DateTime(2026, 8, 5),
      );

      expect(morning.body, isNot(contains('{count}')));
      expect(morning.body, isNot(contains('0つ')));
    });

    test('通知IDは重複しない', () {
      final planned = _plan(now: DateTime(2026, 8, 4, 10, 0));
      final ids = planned.map((n) => n.id).toSet();
      expect(ids, hasLength(planned.length));
    });

    test('同じ日付・種別なら常に同じIDになる', () {
      // 再予約のたびにIDが変わると、取り消し漏れで通知が二重になる。
      final first = _plan(now: DateTime(2026, 8, 4, 10, 0), horizonDays: 3);
      final second = _plan(now: DateTime(2026, 8, 4, 11, 0), horizonDays: 3);

      for (final notification in second) {
        final matching = first.where(
          (n) => n.cardDate == notification.cardDate && n.kind == notification.kind,
        );
        if (matching.isEmpty) continue;
        expect(matching.first.id, notification.id);
      }
    });

    test('iOSの保留通知の上限64件に収まる', () {
      // 1日2件 × 予約期間。上限を超えると古いものから切り捨てられてしまう。
      final planned = _plan(now: DateTime(2026, 8, 4, 0, 1));
      expect(planned.length, lessThanOrEqualTo(64));
      expect(
        planned.length,
        (AppConfig.notificationScheduleHorizonDays + 1) * 2,
      );
    });

    test('時系列順に並ぶ', () {
      final planned = _plan(now: DateTime(2026, 8, 4, 10, 0));
      for (var i = 1; i < planned.length; i++) {
        expect(
          planned[i].scheduledAt.isBefore(planned[i - 1].scheduledAt),
          isFalse,
        );
      }
    });
  });
}
