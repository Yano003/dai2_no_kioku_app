import '../../core/app_config.dart';
import 'number_normalizer.dart';
import 'parsed_schedule.dart';

/// 発話テキストから予定を解析する。
///
/// 対応範囲は要件定義書 5章「対応する話し方」の表を基準とする。
/// 表に無い言い方は日付を確定させず、聞き取った文をそのまま予定名として
/// 返し、登録確認画面（S-03）で利用者に手直ししてもらう。
///
/// 外部 AI サービスは使用せず、規則ベースで解析する。（要件定義書 10章 前提2）
class ScheduleParser {
  ScheduleParser({DateTime? now})
      : _today = _dateOnly(now ?? DateTime.now());

  /// 「今日」の基準日。テストから固定できるようにコンストラクタで受ける。
  final DateTime _today;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static const _weekdayChars = {
    '月': DateTime.monday,
    '火': DateTime.tuesday,
    '水': DateTime.wednesday,
    '木': DateTime.thursday,
    '金': DateTime.friday,
    '土': DateTime.saturday,
    '日': DateTime.sunday,
  };

  /// セグメントの先頭が日付表現かどうかの判定。発話の分割に使う。
  static final _segmentStartPattern = RegExp(
    r'^(今日|本日|明日|あした|あす|明後日|あさって|毎日|毎朝|毎晩|毎週|'
    r'今度の|来週|今週|来月|\d{1,2}月\d{1,2}日|\d{1,2}日|[月火水木金土日]曜)',
  );

  /// 発話を複数の予定に分割する区切り候補。
  static final _delimiterPattern =
      RegExp(r'(、|。|,|\.|それから|そのあと|あとは|あと|次に)');

  /// 発話テキストを解析して予定のリストを返す。
  ///
  /// 複数の予定をまとめて発話した場合は複数件を返す。（要件定義書 4.3）
  List<ParsedSchedule> parse(String rawText) {
    final normalized = normalizeNumbers(rawText);
    if (normalized.isEmpty) return const [];

    return _splitSegments(normalized)
        .map(_parseSegment)
        // 予定名も日付も取れなかったセグメントは捨てる。日付だけ取れた場合は
        // 予定名を空のまま残し、S-03 で入力してもらう。
        .where((schedule) => schedule.title.isNotEmpty || schedule.dateWasSpecified)
        .toList(growable: false);
  }

  /// 発話を予定ごとのセグメントへ分割する。
  ///
  /// 区切り文字で機械的に切ると「今日、牛乳を買う」が壊れるため、
  /// 区切りの直後が日付表現で始まる場合にのみ分割する。
  List<String> _splitSegments(String text) {
    final segments = <String>[];
    var start = 0;

    for (final match in _delimiterPattern.allMatches(text)) {
      if (match.start < start) continue;
      final rest = text.substring(match.end).trimLeft();
      if (rest.isEmpty) continue;
      if (!_segmentStartPattern.hasMatch(rest)) continue;

      final segment = text.substring(start, match.start).trim();
      if (segment.isNotEmpty) segments.add(segment);
      start = match.end;
    }

    final tail = text.substring(start).trim();
    if (tail.isNotEmpty) segments.add(tail);

    return segments.isEmpty ? [text.trim()] : segments;
  }

  ParsedSchedule _parseSegment(String segment) {
    var remainder = segment;

    final dateResult = _extractDate(remainder);
    if (dateResult != null) remainder = dateResult.remainder;

    final timeResult = _extractTime(remainder);
    if (timeResult != null) remainder = timeResult.remainder;

    final title = _cleanTitle(remainder);

    return ParsedSchedule(
      // 日付・時刻が取れなければ、聞き取った文がそのまま予定名になる。
      // （要件定義書 5章「上記以外の言い方」）
      title: title,
      sourceText: segment,
      date: dateResult?.date,
      time: timeResult?.time,
      repeat: dateResult?.repeat ?? RepeatType.none,
      weekday: dateResult?.weekday,
      dateWasSpecified: dateResult != null,
      isExtension: dateResult?.isExtension ?? false,
    );
  }

  // ---------------------------------------------------------------------------
  // 日付・繰り返しの抽出
  // ---------------------------------------------------------------------------

  _DateMatch? _extractDate(String text) {
    for (final rule in _dateRules) {
      if (rule.isExtension && !AppConfig.enableParserExtensions) continue;

      final match = rule.pattern.firstMatch(text);
      if (match == null) continue;

      final resolved = rule.resolve(this, match);
      if (resolved == null) {
        // 日付らしき語は聞き取れたが、実在しない日付だった場合
        // （例:「2月30日」）。下位の規則で当て推量をすると
        // 「30日」を拾って別の日を登録してしまうため、ここで打ち切り、
        // 日付未確定として S-03 の手直しに委ねる。
        return null;
      }

      return resolved.withRemainder(_removeSpan(text, match.start, match.end));
    }
    return null;
  }

  /// 日付表現のルール。上から順に評価し、最初に一致したものを採用する。
  ///
  /// 「1月2日」を「2日」より先に、「毎週水曜」を「水曜は」より先に
  /// 評価する必要があるため、順序に意味がある。
  static final List<_DateRule> _dateRules = [
    // 毎日／毎朝／毎晩 （要件定義書 5章「毎日」）
    _DateRule(
      pattern: RegExp(r'毎日|毎朝|毎晩|毎晩|毎夜'),
      resolve: (parser, match) => _DateMatch(
        date: parser._today,
        repeat: RepeatType.daily,
      ),
    ),

    // 毎週◯曜日 （要件定義書 5章「毎週」）
    _DateRule(
      pattern: RegExp(r'毎週\s*([月火水木金土日])曜日?'),
      resolve: (parser, match) {
        final weekday = _weekdayChars[match.group(1)!]!;
        return _DateMatch(
          date: parser._nextWeekdayOnOrAfterToday(weekday),
          repeat: RepeatType.weekly,
          weekday: weekday,
        );
      },
    ),

    // 今度の◯曜日 （要件定義書 5章「曜日指定」）
    _DateRule(
      pattern: RegExp(r'今度の\s*([月火水木金土日])曜日?'),
      resolve: (parser, match) => _DateMatch(
        date: parser._nextWeekdayAfterToday(_weekdayChars[match.group(1)!]!),
      ),
    ),

    // 来週の◯曜日 （要件定義書 5章「曜日指定」）
    _DateRule(
      pattern: RegExp(r'来週の?\s*([月火水木金土日])曜日?'),
      resolve: (parser, match) => _DateMatch(
        date: parser._weekdayInWeekOffset(
          _weekdayChars[match.group(1)!]!,
          weekOffset: 1,
        ),
      ),
    ),

    // 今週の◯曜日（拡張。5章の表には無い）
    _DateRule(
      isExtension: true,
      pattern: RegExp(r'今週の?\s*([月火水木金土日])曜日?'),
      resolve: (parser, match) => _DateMatch(
        date: parser._weekdayInWeekOffset(
          _weekdayChars[match.group(1)!]!,
          weekOffset: 0,
        ),
        isExtension: true,
      ),
    ),

    // ◯曜は （要件定義書 5章「毎週」の「◯曜日は」）
    //
    // 「今度の／来週の／今週の／毎週」を伴う言い方より必ず後に評価すること。
    // 先に評価すると「来週の月曜は歯医者」が毎週の繰り返し予定になってしまう。
    _DateRule(
      pattern: RegExp(r'([月火水木金土日])曜日?\s*は'),
      resolve: (parser, match) {
        final weekday = _weekdayChars[match.group(1)!]!;
        return _DateMatch(
          date: parser._nextWeekdayOnOrAfterToday(weekday),
          repeat: RepeatType.weekly,
          weekday: weekday,
        );
      },
    ),

    // 来月◯日（拡張）
    _DateRule(
      isExtension: true,
      pattern: RegExp(r'来月\s*(\d{1,2})日'),
      resolve: (parser, match) {
        final day = int.parse(match.group(1)!);
        final base = DateTime(parser._today.year, parser._today.month + 1);
        if (!_isValidDay(base.year, base.month, day)) return null;
        return _DateMatch(
          date: DateTime(base.year, base.month, day),
          isExtension: true,
        );
      },
    ),

    // ◯月◯日 （要件定義書 5章「日付指定」）
    _DateRule(
      pattern: RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日'),
      resolve: (parser, match) {
        final month = int.parse(match.group(1)!);
        final day = int.parse(match.group(2)!);
        if (month < 1 || month > 12) return null;
        final date = parser._resolveMonthDay(month, day);
        return date == null ? null : _DateMatch(date: date);
      },
    ),

    // 明後日（拡張）
    _DateRule(
      isExtension: true,
      pattern: RegExp(r'明後日|あさって'),
      resolve: (parser, match) => _DateMatch(
        date: parser._today.add(const Duration(days: 2)),
        isExtension: true,
      ),
    ),

    // 明日 （要件定義書 5章「翌日」）
    _DateRule(
      pattern: RegExp(r'明日|あした|あす'),
      resolve: (parser, match) => _DateMatch(
        date: parser._today.add(const Duration(days: 1)),
      ),
    ),

    // 今日 （要件定義書 5章「当日」）
    _DateRule(
      pattern: RegExp(r'今日|本日|きょう'),
      resolve: (parser, match) => _DateMatch(date: parser._today),
    ),

    // ◯日 （要件定義書 5章「日付指定」）
    // 「15時」等を巻き込まないよう、直前が数字でないことを確認する。
    _DateRule(
      pattern: RegExp(r'(?<!\d)(\d{1,2})\s*日(?!間)'),
      resolve: (parser, match) {
        final day = int.parse(match.group(1)!);
        if (day < 1 || day > 31) return null;
        final date = parser._resolveDayOfMonth(day);
        return date == null ? null : _DateMatch(date: date);
      },
    ),

    // ◯曜（単独。拡張。「今度の◯曜」と同じ扱いにする）
    _DateRule(
      isExtension: true,
      pattern: RegExp(r'([月火水木金土日])曜日?'),
      resolve: (parser, match) => _DateMatch(
        date: parser._nextWeekdayAfterToday(_weekdayChars[match.group(1)!]!),
        isExtension: true,
      ),
    ),
  ];

  /// 今日より後で最初に来る指定曜日。今日が同じ曜日なら7日後。
  DateTime _nextWeekdayAfterToday(int weekday) {
    var diff = (weekday - _today.weekday) % 7;
    if (diff <= 0) diff += 7;
    return _today.add(Duration(days: diff));
  }

  /// 今日を含めて次に来る指定曜日。繰り返し予定の基準日に使う。
  DateTime _nextWeekdayOnOrAfterToday(int weekday) {
    final diff = (weekday - _today.weekday) % 7;
    return _today.add(Duration(days: diff < 0 ? diff + 7 : diff));
  }

  /// 週（月曜始まり）を [weekOffset] 週ずらした上での指定曜日。
  DateTime _weekdayInWeekOffset(int weekday, {required int weekOffset}) {
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    return monday.add(Duration(days: weekOffset * 7 + (weekday - 1)));
  }

  /// 「◯月◯日」の解決。今年の該当日が既に過ぎていれば翌年とみなす。
  ///
  /// 実在しない日付（2月30日など）の場合は null を返す。DateTime は
  /// DateTime(2026, 2, 30) を 2026年3月2日 へ繰り上げてしまうため、
  /// 生成前に実在を確認する必要がある。
  DateTime? _resolveMonthDay(int month, int day) {
    for (final year in [_today.year, _today.year + 1]) {
      if (!_isValidDay(year, month, day)) continue;
      final candidate = DateTime(year, month, day);
      if (!candidate.isBefore(_today)) return candidate;
    }
    return null;
  }

  /// 「◯日」の解決。今月の該当日が既に過ぎていれば翌月とみなす。
  DateTime? _resolveDayOfMonth(int day) {
    for (var offset = 0; offset < 13; offset++) {
      final base = DateTime(_today.year, _today.month + offset);
      if (!_isValidDay(base.year, base.month, day)) continue;
      final candidate = DateTime(base.year, base.month, day);
      if (!candidate.isBefore(_today)) return candidate;
    }
    return null;
  }

  static bool _isValidDay(int year, int month, int day) {
    if (day < 1) return false;
    final lastDay = DateTime(year, month + 1, 0).day;
    return day <= lastDay;
  }

  // ---------------------------------------------------------------------------
  // 時刻の抽出
  // ---------------------------------------------------------------------------

  static final _timePatterns = [
    RegExp(r'(午前|午後)?\s*(\d{1,2})\s*時\s*(\d{1,2})\s*分'),
    RegExp(r'(午前|午後)?\s*(\d{1,2})\s*時(?!間)'),
    RegExp(r'(?<!\d)(\d{1,2}):(\d{2})(?!\d)'),
  ];

  _TimeMatch? _extractTime(String text) {
    for (var i = 0; i < _timePatterns.length; i++) {
      final match = _timePatterns[i].firstMatch(text);
      if (match == null) continue;

      final int rawHour;
      final int minute;
      String? meridiem;

      if (i == 2) {
        rawHour = int.parse(match.group(1)!);
        minute = int.parse(match.group(2)!);
      } else {
        meridiem = match.group(1);
        rawHour = int.parse(match.group(2)!);
        minute = i == 0 ? int.parse(match.group(3)!) : 0;
      }

      var hour = rawHour;
      if (meridiem == '午後' && hour < 12) hour += 12;
      if (meridiem == '午前' && hour == 12) hour = 0;
      if (hour > 23 || minute > 59) continue;

      return _TimeMatch(
        time: ClockTime(hour, minute),
        remainder: _removeSpan(text, match.start, match.end),
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 予定名の整形
  // ---------------------------------------------------------------------------

  static String _removeSpan(String text, int start, int end) =>
      '${text.substring(0, start)} ${text.substring(end)}';

  /// 日付・時刻を取り除いた残りを予定名として整える。
  ///
  /// 「21日に税金の支払い」→ 日付を除去 →「に税金の支払い」→「税金の支払い」
  static String _cleanTitle(String text) {
    var title = text.trim();

    // 先頭に残った助詞・句読点を落とす。落としすぎると予定名が壊れるため、
    // 単独の助詞1文字と句読点のみを対象にする。
    final leading = RegExp(r'^[\s、。,\.]*(?:[にはのを])?[\s、。,\.]*');
    String previous;
    do {
      previous = title;
      title = title.replaceFirst(leading, '').trim();
    } while (title != previous);

    title = title.replaceFirst(RegExp(r'[\s、。,\.]+$'), '');

    // 除去処理で生じた連続空白を1つに畳む。
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

// -----------------------------------------------------------------------------
// 内部用の中間データ
// -----------------------------------------------------------------------------

class _DateRule {
  const _DateRule({
    required this.pattern,
    required this.resolve,
    this.isExtension = false,
  });

  final RegExp pattern;
  final _DateMatch? Function(ScheduleParser parser, RegExpMatch match) resolve;
  final bool isExtension;
}

class _DateMatch {
  const _DateMatch({
    required this.date,
    this.repeat = RepeatType.none,
    this.weekday,
    this.isExtension = false,
    this.remainder = '',
  });

  final DateTime date;
  final RepeatType repeat;
  final int? weekday;
  final bool isExtension;
  final String remainder;

  _DateMatch withRemainder(String value) => _DateMatch(
        date: date,
        repeat: repeat,
        weekday: weekday,
        isExtension: isExtension,
        remainder: value,
      );
}

class _TimeMatch {
  const _TimeMatch({required this.time, required this.remainder});

  final ClockTime time;
  final String remainder;
}
