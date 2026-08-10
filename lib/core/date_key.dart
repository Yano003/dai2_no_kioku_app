/// 日付をキー文字列（yyyy-MM-dd）として扱うためのユーティリティ。
///
/// カードも完了状態も「日付」単位で成立する仕様のため、時刻成分を持たない
/// 表現を1箇所に固定しておく。端末のタイムゾーンをそのまま用いる。
library;

/// 時刻成分を落として日付のみにする。
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 日付を yyyy-MM-dd 形式のキーへ変換する。
String toDateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month-$day';
}

/// yyyy-MM-dd 形式のキーを日付へ戻す。
DateTime fromDateKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// 2つの日付が同じ日かどうか。
bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// [from] から [to] までの日付を列挙する（両端を含む）。
Iterable<DateTime> dateRange(DateTime from, DateTime to) sync* {
  var current = dateOnly(from);
  final last = dateOnly(to);
  while (!current.isAfter(last)) {
    yield current;
    current = current.add(const Duration(days: 1));
  }
}
