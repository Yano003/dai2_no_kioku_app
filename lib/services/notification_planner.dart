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
/// ■ なぜ日付ごとに予約するのか
/// サーバーを持たない構成のため、通知が発火する瞬間にアプリが内容を
/// 組み立てることはできない。文面は予定の有無によらず同じだが、タップして
/// 開くカードの日付（[PlannedNotification.cardDate]）は日ごとに違うため、
/// 1件ずつ予約する必要がある。
///
/// アプリ起動時と予定の登録・修正・削除のたびに
/// [AppConfig.notificationScheduleHorizonDays] 日先までを予約し直す。
/// iOS の保留通知の上限は64件、1日2件なので 14日 × 2 = 28件で収まる。
///
/// [countsByDate] は文面には影響せず、予定が0件の日に通知を出すかどうかの
/// 判定（[AppConfig.notifyOnEmptyDays]）にのみ使う。
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

    // 当日朝の通知。その日のカードへ誘導する。
    // 文面は予定の有無で変えない。（お客様ご指摘 2026/08/17）
    final morningAt = _at(date, morningNotifyTime);
    if (morningAt.isAfter(now) &&
        (countFor(date) > 0 || AppConfig.notifyOnEmptyDays)) {
      planned.add(
        PlannedNotification(
          id: _idFor(date, NotificationKind.morning),
          scheduledAt: morningAt,
          title: AppStrings.notificationMorningTitle,
          body: AppStrings.notificationMorningBody,
          cardDate: date,
          kind: NotificationKind.morning,
        ),
      );
    }

    // 前日夜の通知。タップすると翌日のカードを直接開く。
    // 当日のカードを挟まないこと。（お客様ご指摘 2026/08/17）
    final nextDay = date.add(const Duration(days: 1));
    final nightAt = _at(date, nightNotifyTime);
    if (nightAt.isAfter(now) &&
        (countFor(nextDay) > 0 || AppConfig.notifyOnEmptyDays)) {
      planned.add(
        PlannedNotification(
          id: _idFor(date, NotificationKind.night),
          scheduledAt: nightAt,
          title: AppStrings.notificationNightTitle,
          body: AppStrings.notificationNightBody,
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
