import '../../core/app_config.dart';
import '../../core/clock_time.dart';

// ClockTime は core に置いているが、解析結果とセットで使われることが多いため
// ここから再公開しておく。
export '../../core/clock_time.dart';

/// 発話1件から解析した予定1件分の結果。
///
/// 要件定義書 5章「対応する話し方」の解析結果を表す。
class ParsedSchedule {
  const ParsedSchedule({
    required this.title,
    required this.sourceText,
    this.date,
    this.time,
    this.repeat = RepeatType.none,
    this.weekday,
    this.dateWasSpecified = false,
    this.isExtension = false,
  });

  /// 予定名。発話から日付・時刻の語を除いた部分。（要件定義書 5章）
  final String title;

  /// 解析元の発話（の該当セグメント）。修正画面での参照用に保持する。
  final String sourceText;

  /// 対象日。繰り返し予定の場合は基準日。
  /// null は「日付を聞き取れなかった」ことを示し、登録確認画面（S-03）で
  /// 利用者に手直ししてもらう。（要件定義書 4.9 / 5章）
  final DateTime? date;

  /// 時刻。null は終日扱い。（要件定義書 7.2）
  final ClockTime? time;

  /// 繰り返し種別。
  final RepeatType repeat;

  /// [RepeatType.weekly] のときの曜日。DateTime.monday(1)〜DateTime.sunday(7)。
  final int? weekday;

  /// 日付を表す語を実際に聞き取れたか。
  ///
  /// false の場合、[date] は「今日」として補完されたか未確定であり、
  /// S-03 で日付の確認を促す必要がある。
  final bool dateWasSpecified;

  /// 要件定義書5章の表の範囲外の言い方（「明後日」等）を
  /// 拡張ルールで解析した結果か。精度保証の対象外である旨の判別に使う。
  final bool isExtension;

  ParsedSchedule copyWith({
    String? title,
    DateTime? date,
    ClockTime? time,
    RepeatType? repeat,
    int? weekday,
    bool? dateWasSpecified,
    bool? isExtension,
  }) {
    return ParsedSchedule(
      title: title ?? this.title,
      sourceText: sourceText,
      date: date ?? this.date,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
      weekday: weekday ?? this.weekday,
      dateWasSpecified: dateWasSpecified ?? this.dateWasSpecified,
      isExtension: isExtension ?? this.isExtension,
    );
  }

  @override
  String toString() => 'ParsedSchedule(title: $title, date: $date, '
      'time: $time, repeat: $repeat, weekday: $weekday, '
      'dateWasSpecified: $dateWasSpecified)';
}
