import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/domain/parser/number_normalizer.dart';
import 'package:dai2_no_kioku/domain/parser/parsed_schedule.dart';
import 'package:dai2_no_kioku/domain/parser/schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 基準日：2026年8月4日（火曜日）。
///
/// 「今度の◯曜」「◯日」の解決結果が基準日に依存するため、テストでは固定する。
final _today = DateTime(2026, 8, 4);

ScheduleParser _parser() => ScheduleParser(now: _today);

ParsedSchedule _parseOne(String text) {
  final results = _parser().parse(text);
  expect(results, hasLength(1), reason: '「$text」は1件に解析されるはず');
  return results.single;
}

void main() {
  // ===========================================================================
  // 要件定義書 5章「対応する話し方」の表。
  // ここに挙げた発話は精度保証の対象であり、全件が通ることを受け入れ条件とする。
  // ===========================================================================
  group('5章 対応する話し方', () {
    test('当日：今日、牛乳を買う', () {
      final result = _parseOne('今日、牛乳を買う');
      expect(result.title, '牛乳を買う');
      expect(result.date, DateTime(2026, 8, 4));
      expect(result.repeat, RepeatType.none);
      expect(result.dateWasSpecified, isTrue);
    });

    test('翌日：明日、帰りに牛乳を買う', () {
      final result = _parseOne('明日、帰りに牛乳を買う');
      expect(result.title, '帰りに牛乳を買う');
      expect(result.date, DateTime(2026, 8, 5));
    });

    test('日付指定：21日に税金の支払い', () {
      final result = _parseOne('21日に税金の支払い');
      expect(result.title, '税金の支払い');
      expect(result.date, DateTime(2026, 8, 21));
    });

    test('日付指定：8月21日に税金の支払い', () {
      final result = _parseOne('8月21日に税金の支払い');
      expect(result.title, '税金の支払い');
      expect(result.date, DateTime(2026, 8, 21));
    });

    test('曜日指定：今度の月曜、母さんに電話', () {
      final result = _parseOne('今度の月曜、母さんに電話');
      expect(result.title, '母さんに電話');
      // 基準日が火曜なので、次の月曜は6日後の8月10日。
      expect(result.date, DateTime(2026, 8, 10));
      expect(result.repeat, RepeatType.none);
    });

    test('曜日指定：来週の金曜に同窓会', () {
      final result = _parseOne('来週の金曜に同窓会');
      expect(result.title, '同窓会');
      expect(result.date, DateTime(2026, 8, 14));
    });

    test('毎日：毎日、朝食後に薬', () {
      final result = _parseOne('毎日、朝食後に薬');
      expect(result.title, '朝食後に薬');
      expect(result.repeat, RepeatType.daily);
      expect(result.date, DateTime(2026, 8, 4));
    });

    test('毎日：毎朝、薬を飲む', () {
      final result = _parseOne('毎朝、薬を飲む');
      expect(result.title, '薬を飲む');
      expect(result.repeat, RepeatType.daily);
    });

    test('毎週：水曜はゴミの日', () {
      final result = _parseOne('水曜はゴミの日');
      expect(result.title, 'ゴミの日');
      expect(result.repeat, RepeatType.weekly);
      expect(result.weekday, DateTime.wednesday);
      // 基準日の火曜から見て次の水曜が基準日になる。
      expect(result.date, DateTime(2026, 8, 5));
    });

    test('毎週：毎週水曜日にジム', () {
      final result = _parseOne('毎週水曜日にジム');
      expect(result.title, 'ジム');
      expect(result.repeat, RepeatType.weekly);
      expect(result.weekday, DateTime.wednesday);
    });

    test('時刻：明日15時に歯医者', () {
      final result = _parseOne('明日15時に歯医者');
      expect(result.title, '歯医者');
      expect(result.date, DateTime(2026, 8, 5));
      expect(result.time, const ClockTime(15, 0));
    });

    test('時刻：◯時◯分', () {
      final result = _parseOne('明日9時30分に病院');
      expect(result.title, '病院');
      expect(result.time, const ClockTime(9, 30));
    });
  });

  // ===========================================================================
  // 音声認識の表記ゆれ。同じ発話でも端末により表記が変わるため吸収する。
  // ===========================================================================
  group('表記ゆれの吸収', () {
    test('漢数字：明日十五時に歯医者', () {
      expect(_parseOne('明日十五時に歯医者').time, const ClockTime(15, 0));
    });

    test('全角数字：明日１５時に歯医者', () {
      expect(_parseOne('明日１５時に歯医者').time, const ClockTime(15, 0));
    });

    test('「時半」：明日15時半に歯医者', () {
      expect(_parseOne('明日15時半に歯医者').time, const ClockTime(15, 30));
    });

    test('午後表記：午後3時に会議', () {
      final result = _parseOne('午後3時に会議');
      expect(result.title, '会議');
      expect(result.time, const ClockTime(15, 0));
      // 日付の語が無いので日付は未確定。S-03 で手直ししてもらう。
      expect(result.date, isNull);
      expect(result.dateWasSpecified, isFalse);
    });

    test('午前表記：明日午前10時に集合', () {
      expect(_parseOne('明日午前10時に集合').time, const ClockTime(10, 0));
    });

    test('コロン表記：明日 9:30 に病院', () {
      expect(_parseOne('明日 9:30 に病院').time, const ClockTime(9, 30));
    });
  });

  // ===========================================================================
  // 日付の解決規則。仕様に明記が無く、レビューで暫定合意した挙動。
  // ===========================================================================
  group('日付の解決規則', () {
    test('◯日が今月で既に過ぎていれば翌月とみなす', () {
      // 基準日は8月4日なので「3日」は9月3日。
      expect(_parseOne('3日に病院').date, DateTime(2026, 9, 3));
    });

    test('◯月◯日が今年で既に過ぎていれば翌年とみなす', () {
      expect(_parseOne('1月5日に初詣').date, DateTime(2027, 1, 5));
    });

    test('今度の◯曜が今日と同じ曜日なら7日後', () {
      // 基準日は火曜。
      expect(_parseOne('今度の火曜に集まり').date, DateTime(2026, 8, 11));
    });

    test('存在しない日付は日付として採用しない', () {
      // 2月30日は存在しないため、日付未確定として扱う。
      final result = _parseOne('2月30日に打ち合わせ');
      expect(result.dateWasSpecified, isFalse);
    });
  });

  // ===========================================================================
  // 複数予定の分割。（要件定義書 4.3）
  // ===========================================================================
  group('複数予定の分割', () {
    test('区切りの後が日付表現なら分割する', () {
      final results = _parser().parse('明日は歯医者、来週の月曜に電話');
      expect(results, hasLength(2));

      expect(results[0].title, '歯医者');
      expect(results[0].date, DateTime(2026, 8, 5));

      expect(results[1].title, '電話');
      expect(results[1].date, DateTime(2026, 8, 10));
    });

    test('区切りの後が日付表現でなければ分割しない', () {
      // 「今日、牛乳を買う」を読点で切ってしまうと予定名が壊れる。
      expect(_parser().parse('今日、牛乳を買う'), hasLength(1));
    });

    test('接続詞での分割', () {
      final results = _parser().parse('今日は買い物、それから明日は病院');
      expect(results, hasLength(2));
      expect(results[0].title, '買い物');
      expect(results[1].title, '病院');
      expect(results[1].date, DateTime(2026, 8, 5));
    });
  });

  // ===========================================================================
  // 対応範囲外の言い方。（要件定義書 5章「上記以外の言い方」/ 4.9）
  // ===========================================================================
  group('対応範囲外の言い方', () {
    test('日付が取れない発話は全文を予定名として残す', () {
      final result = _parseOne('そろそろ床屋に行きたい');
      expect(result.title, 'そろそろ床屋に行きたい');
      expect(result.date, isNull);
      expect(result.dateWasSpecified, isFalse);
    });

    test('聞き取り結果が空なら何も返さない', () {
      expect(_parser().parse(''), isEmpty);
      expect(_parser().parse('   '), isEmpty);
    });

    test('曜日を伴う単発予定が毎週予定にならない', () {
      // 「◯曜は」の規則より「来週の◯曜」の規則が先に評価される必要がある。
      final result = _parseOne('来週の月曜は歯医者');
      expect(result.repeat, RepeatType.none);
      expect(result.date, DateTime(2026, 8, 10));
      expect(result.title, '歯医者');
    });
  });

  // ===========================================================================
  // 数値正規化の単体テスト。
  // ===========================================================================
  group('漢数字の変換', () {
    test('一桁', () {
      expect(kanjiToInt('三'), 3);
      expect(kanjiToInt('九'), 9);
    });

    test('十を含む', () {
      expect(kanjiToInt('十'), 10);
      expect(kanjiToInt('十五'), 15);
      expect(kanjiToInt('二十'), 20);
      expect(kanjiToInt('二十一'), 21);
      expect(kanjiToInt('三十一'), 31);
    });

    test('対象外は null', () {
      expect(kanjiToInt('百'), isNull);
      expect(kanjiToInt('あ'), isNull);
      expect(kanjiToInt(''), isNull);
    });

    test('単位を伴わない漢数字は変換しない', () {
      // 予定名に含まれる漢数字を壊さないこと。
      expect(normalizeNumbers('三田さんに電話'), '三田さんに電話');
    });

    test('単位を伴う漢数字は変換する', () {
      expect(normalizeNumbers('十五時'), '15時');
      expect(normalizeNumbers('二十一日'), '21日');
    });
  });
}
