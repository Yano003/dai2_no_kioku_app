import '../../core/app_config.dart';
import '../../core/date_key.dart';
import '../../data/models/schedule.dart';
import '../parser/parsed_schedule.dart';

/// 安心カードの表示パターン。（要件定義書 4.5「カードの表示パターン」）
enum CardVariant {
  /// 前日夜。翌日のカードを、その前夜に見ている状態。
  /// 「明日はこれだけ覚えておけば大丈夫です」＋おやすみなさいボタン。
  previousNight,

  /// 当日朝。「今日は◯つ覚えておけば大丈夫です」＋いってらっしゃいボタン。
  morning,

  /// 当日日中。予定一覧＋確認しましたボタン。
  daytime,

  /// 当日夜、その日の予定をすべて完了した状態。
  nightAllDone,

  /// 当日夜、やり残しがある状態。
  nightRemaining,

  /// 明後日以降の未来のカード。
  future,

  /// 昨日以前の過去のカード（履歴）。
  past,
}

/// 1日分の安心カード。
///
/// 表示パターンの判定に必要な情報をすべて持ち、UI 側は分岐せずに描画できる。
class DayCard {
  const DayCard({
    required this.date,
    required this.entries,
    required this.variant,
    required this.acknowledged,
    required this.dayOffset,
    this.hiddenCount = 0,
  });

  /// 今日から何日離れた日のカードか。今日=0、明日=1、昨日=-1。
  ///
  /// カードの名前（今日の安心カード／明日の安心カード／…）の出し分けに使う。
  /// [variant] だけでは、日中に見ている「明日のカード」と「明後日のカード」を
  /// 区別できないため、日付の関係を別に持つ。
  final int dayOffset;

  /// このカードの日付。
  final DateTime date;

  /// その日に表示する予定一覧（完了状態つき）。
  /// 最大 [AppConfig.maxSchedulesPerDay] 件。（要件定義書 4.5）
  final List<ScheduleEntry> entries;

  /// 上限を超えて表示から外れた件数。通常は 0。
  final int hiddenCount;

  /// 表示パターン。
  final CardVariant variant;

  /// 「確認しました」を押し済みか。
  final bool acknowledged;

  /// 予定が1件も無い日。S-10（空表示）で扱う。
  bool get isEmpty => entries.isEmpty;

  int get total => entries.length;

  int get completedCount =>
      entries.where((entry) => entry.isCompleted).length;

  int get remainingCount => total - completedCount;

  bool get allCompleted => entries.isNotEmpty && remainingCount == 0;

  /// 完了チェックを操作できるカードか。
  ///
  /// 未来の予定を前もって完了にできてしまうと、体験としても集計としても
  /// 破綻するため、当日以前のカードに限る。
  bool get isCheckable =>
      variant != CardVariant.future && variant != CardVariant.previousNight;

  /// 予定の一覧を出すカードか。
  ///
  /// 当日夜のカードは一日を締めるための表示で、予定一覧は出さない。
  /// （要件定義書 4.5 の表・画面イメージ「当日夜①」）
  bool get showsEntries =>
      variant != CardVariant.nightAllDone &&
      variant != CardVariant.nightRemaining;
}

/// カードを組み立てる。
///
/// 表示パターンの時間境界は要件定義書に定義が無いため、利用者が設定した
/// 2つの通知時刻を境界として使う。通知時刻を変えるとカードの表情も
/// 連動するため、体験が一貫する。（レビュー追加提起 No.14）
DayCard buildDayCard({
  required DateTime date,
  required List<ScheduleEntry> entries,
  required DateTime now,
  required ClockTime morningNotifyTime,
  required ClockTime nightNotifyTime,
  bool acknowledged = false,
}) {
  final cardDate = dateOnly(date);
  final today = dateOnly(now);
  final currentTime = ClockTime(now.hour, now.minute);

  final allCompleted =
      entries.isNotEmpty && entries.every((entry) => entry.isCompleted);

  // 1枚のカードに表示する予定は最大 [AppConfig.maxSchedulesPerDay] 件。
  // （要件定義書 4.5 / 2.2）
  // 登録時に上限を掛けているため通常は超えないが、繰り返し予定が重なると
  // 超え得るため、表示側でも上限を守る。
  final visible = entries.length > AppConfig.maxSchedulesPerDay
      ? entries.sublist(0, AppConfig.maxSchedulesPerDay)
      : entries;

  return DayCard(
    date: cardDate,
    entries: visible,
    hiddenCount: entries.length - visible.length,
    acknowledged: acknowledged,
    dayOffset: cardDate.difference(today).inDays,
    variant: _resolveVariant(
      cardDate: cardDate,
      today: today,
      currentTime: currentTime,
      morningNotifyTime: morningNotifyTime,
      nightNotifyTime: nightNotifyTime,
      allCompleted: allCompleted,
    ),
  );
}

CardVariant _resolveVariant({
  required DateTime cardDate,
  required DateTime today,
  required ClockTime currentTime,
  required ClockTime morningNotifyTime,
  required ClockTime nightNotifyTime,
  required bool allCompleted,
}) {
  final dayDiff = cardDate.difference(today).inDays;

  if (dayDiff < 0) return CardVariant.past;

  if (dayDiff == 0) {
    // 夜の通知時刻を過ぎたら、その日を締める表示に切り替える。
    if (currentTime.compareTo(nightNotifyTime) >= 0) {
      return allCompleted ? CardVariant.nightAllDone : CardVariant.nightRemaining;
    }
    // 朝の通知時刻から正午までを「当日朝」とする。
    final midday = const ClockTime(AppConfig.middayBoundaryHour, 0);
    if (currentTime.compareTo(morningNotifyTime) >= 0 &&
        currentTime.compareTo(midday) < 0) {
      return CardVariant.morning;
    }
    return CardVariant.daytime;
  }

  if (dayDiff == 1) {
    // 夜の通知時刻を過ぎていれば、翌日のカードが主役になる。
    if (currentTime.compareTo(nightNotifyTime) >= 0) {
      return CardVariant.previousNight;
    }
    return CardVariant.future;
  }

  return CardVariant.future;
}
