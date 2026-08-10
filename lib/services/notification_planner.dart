import '../core/app_config.dart';
import '../core/app_strings.dart';
import '../core/date_key.dart';
import '../domain/parser/parsed_schedule.dart';

/// 予約する通知1件分。
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.cardDate,
    required this.kind,
  });

  /// 通知 ID。日付と種別から一意に決まる。再計算しても同じ値になるため、
  /// 予約の重複や取り消し漏れが起きない。
  final int id;

  /// 通知を出す日時（端末のローカル時刻）。
  final DateTime scheduledAt;

  final String title;
  final String body;

  /// タップしたときに開くカードの日付。（要件定義書 6.3）
  final DateTime cardDate;

  final NotificationKind kind;

  /// 通知タップ時に受け取るペイロード。
  String get payload => 'card:${toDateKey(cardDate)}';
}

enum NotificationKind {
  /// 前日夜。翌日の予定を「準備」として通知する。（要件定義書 6.1）
  night,

  /// 当日朝。当日の予定を「確認」として通知する。（要件定義書 6.1）
  morning,
}

/// 通知の予約内容を組み立てる。
///
/// ■ なぜ事前計算するのか
/// ローカル通知の文面は予約した時点で固定される。「今日は◯つ覚えておけば
/// 大丈夫です」の件数を通知に含めるには、日付ごとに件数を数えた文面を
/// あらかじめ作って予約するしかない。サーバーを持たない構成では、
/// 通知が発火する瞬間にアプリが件数を計算し直すことはできない。
///
/// このため、アプリ起動時と予定の登録・修正・削除のたびに
/// [AppConfig.notificationScheduleHorizonDays] 日先までを予約し直す。
/// iOS の保留通知の上限は64件、1日2件なので 14日 × 2 = 28件で収まる。
List<PlannedNotification> planNotifications({
  required DateTime now,
  required Map<DateTime, int> countsByDate,
  required ClockTime morningNotifyTime,
  required ClockTime nightNotifyTime,
  int horizonDays = AppConfig.notificationScheduleHorizonDays,
}) {
  final today = dateOnly(now);
  final planned = <PlannedNotification>[];

  int countFor(DateTime date) => countsByDate[dateOnly(date)] ?? 0;

  for (var offset = 0; offset <= horizonDays; offset++) {
    final date = today.add(Duration(days: offset));

    // 当日朝の通知。その日の予定を知らせる。
    final morningCount = countFor(date);
    final morningAt = _at(date, morningNotifyTime);
    if (morningAt.isAfter(now) &&
        (morningCount > 0 || AppConfig.notifyOnEmptyDays)) {
      planned.add(
        PlannedNotification(
          id: _idFor(date, NotificationKind.morning),
          scheduledAt: morningAt,
          title: AppStrings.notificationMorningTitle,
          body: morningCount > 0
              ? AppStrings.withCount(
                  AppStrings.notificationMorningBody,
                  morningCount,
                )
              : AppStrings.notificationEmptyMorningBody,
          cardDate: date,
          kind: NotificationKind.morning,
        ),
      );
    }

    // 前日夜の通知。翌日の予定を知らせ、翌日のカードを開く。
    final nextDay = date.add(const Duration(days: 1));
    final nightCount = countFor(nextDay);
    final nightAt = _at(date, nightNotifyTime);
    if (nightAt.isAfter(now) &&
        (nightCount > 0 || AppConfig.notifyOnEmptyDays)) {
      planned.add(
        PlannedNotification(
          id: _idFor(date, NotificationKind.night),
          scheduledAt: nightAt,
          title: AppStrings.notificationNightTitle,
          body: nightCount > 0
              ? AppStrings.notificationNightBody
              : AppStrings.notificationEmptyNightBody,
          cardDate: nextDay,
          kind: NotificationKind.night,
        ),
      );
    }
  }

  planned.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return planned;
}

DateTime _at(DateTime date, ClockTime time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

/// 日付と種別から通知 ID を決める。
///
/// エポックからの経過日数を使うため、同じ日付・同じ種別なら常に同じ ID になる。
/// Android の通知 ID は 32bit 整数のため、この計算値なら十分収まる。
int _idFor(DateTime date, NotificationKind kind) {
  final days = date.difference(DateTime(2020)).inDays;
  return days * 2 + (kind == NotificationKind.morning ? 0 : 1);
}
