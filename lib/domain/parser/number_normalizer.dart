/// 音声認識結果の数値表記ゆれを吸収する正規化処理。
///
/// 端末標準の音声認識は同じ発話に対して「15時」「十五時」「１５時」の
/// いずれも返し得るため、解析の前段で半角アラビア数字へ寄せる。
library;

const _fullWidthDigits = '０１２３４５６７８９';
const _kanjiDigits = {
  '〇': 0,
  '零': 0,
  '一': 1,
  '二': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
};

/// 漢数字の並びを整数に変換する。100未満を想定（月・日・時・分で足りる）。
///
/// 変換できない場合は null を返す。
/// 例: 「十五」→ 15、「二十一」→ 21、「三」→ 3、「十」→ 10
int? kanjiToInt(String source) {
  if (source.isEmpty) return null;

  // 「百」以上は日付・時刻には出現しないため対象外とする。
  if (source.contains('百') || source.contains('千')) return null;

  final tenIndex = source.indexOf('十');
  if (tenIndex < 0) {
    // 「十」を含まない場合は各桁をそのまま連結した表記とみなす。
    // 例: 「三」→ 3、「二〇」→ 20
    var value = 0;
    for (final char in source.split('')) {
      final digit = _kanjiDigits[char];
      if (digit == null) return null;
      value = value * 10 + digit;
    }
    return value;
  }

  final tensPart = source.substring(0, tenIndex);
  final onesPart = source.substring(tenIndex + 1);

  // 「十」の前が無ければ 1（十五 → 15）、あればその値（二十一 → 21）。
  final int tens;
  if (tensPart.isEmpty) {
    tens = 1;
  } else {
    final parsed = _kanjiDigits[tensPart];
    if (parsed == null || tensPart.length != 1) return null;
    tens = parsed;
  }

  // 「十」の後が無ければ 0（二十 → 20）。
  final int ones;
  if (onesPart.isEmpty) {
    ones = 0;
  } else {
    final parsed = _kanjiDigits[onesPart];
    if (parsed == null || onesPart.length != 1) return null;
    ones = parsed;
  }

  return tens * 10 + ones;
}

/// 数値に関わる表記を正規化する。
///
/// 1. 全角英数字・全角スペースを半角へ
/// 2. 月・日・時・分・曜 の直前にある漢数字をアラビア数字へ
/// 3. 「◯時半」を「◯時30分」へ
///
/// 漢数字の変換を単位付きに限定しているのは、予定名に含まれる漢数字
/// （例:「三田さんに電話」）まで壊さないため。
String normalizeNumbers(String input) {
  var text = input;

  // 全角数字 → 半角数字
  for (var i = 0; i < 10; i++) {
    text = text.replaceAll(_fullWidthDigits[i], '$i');
  }
  text = text.replaceAll('　', ' ');
  text = text.replaceAll('：', ':');

  // 単位を伴う漢数字のみアラビア数字へ変換する。
  text = text.replaceAllMapped(
    RegExp(r'([〇零一二三四五六七八九十]+)\s*(月|日|時|分|時間)'),
    (match) {
      final value = kanjiToInt(match.group(1)!);
      if (value == null) return match.group(0)!;
      return '$value${match.group(2)}';
    },
  );

  // 「15時半」→「15時30分」
  text = text.replaceAllMapped(
    RegExp(r'(\d{1,2})\s*時\s*半'),
    (match) => '${match.group(1)}時30分',
  );

  return text.trim();
}
