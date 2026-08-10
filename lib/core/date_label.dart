import 'app_strings.dart';
import 'date_key.dart';

/// 日付の表示文字列を組み立てる。
///
/// intl のロケール初期化を必要とせずに済むよう、曜日名は自前で持つ。
/// 依存を減らすことで、初回起動時の読み込みも軽くなる。
const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

String weekdayLabel(DateTime date) => _weekdayLabels[date.weekday - 1];

/// 「今日」「明日」「昨日」、それ以外は「8月4日（火）」。
///
/// 対象利用者にとって「2026/08/04」より「8月4日（火）」の方が読み取りやすく、
/// 今日との関係が一目で分かることを優先する。
String dateLabel(DateTime date, {DateTime? now}) {
  final target = dateOnly(date);
  final today = dateOnly(now ?? DateTime.now());
  final diff = target.difference(today).inDays;

  if (diff == 0) return AppStrings.cardToday;
  if (diff == 1) return AppStrings.cardTomorrow;
  if (diff == -1) return AppStrings.cardYesterday;

  return '${target.month}月${target.day}日（${weekdayLabel(target)}）';
}

/// 「今日」等の相対表記と、実際の日付を併記した文字列。
///
/// 相対表記だけだと今日が何日か分からず、日付だけだと今日との関係が
/// 分からないため、両方を出す。
String dateLabelWithDate(DateTime date, {DateTime? now}) {
  final target = dateOnly(date);
  final today = dateOnly(now ?? DateTime.now());
  final diff = target.difference(today).inDays;

  if (diff.abs() > 1) return dateLabel(target, now: today);
  return '${dateLabel(target, now: today)}  '
      '${target.month}月${target.day}日（${weekdayLabel(target)}）';
}

/// カードの名前。「今日の安心カード」「7月21日の安心カード」など。
///
/// 日付行（[fullDateLabel]）と重複しないよう、名前側には年と曜日を入れない。
/// [dayOffset] は今日からの日数（今日=0、明日=1、昨日=-1）。
String cardName(int dayOffset, DateTime date) {
  switch (dayOffset) {
    case 0:
      return AppStrings.cardTitleToday;
    case 1:
      return AppStrings.cardTitleTomorrow;
    case -1:
      return AppStrings.cardTitleYesterday;
    default:
      return AppStrings.fill(AppStrings.cardTitleOther, {
        'date': '${date.month}月${date.day}日',
      });
  }
}

/// 「2026年7月21日（火）」形式。カードの日付行に使う。
///
/// 画面イメージのカードは、名前（今日の安心カード）と日付を別の行に分けて
/// 出しているため、年まで含む完全な表記をここで作る。
String fullDateLabel(DateTime date) {
  final target = dateOnly(date);
  return '${target.year}年${target.month}月${target.day}日'
      '（${weekdayLabel(target)}）';
}
