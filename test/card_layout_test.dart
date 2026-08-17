import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/core/clock_time.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/domain/card/day_card.dart';
import 'package:dai2_no_kioku/features/card/card_screen.dart';
import 'package:dai2_no_kioku/features/card/day_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 画面イメージに合わせたカードの構成を固定する。
///
/// 画面イメージのカードは、上から
///   カードの名前 → 日付 → 本文 → 予定一覧 → 締めの一文 → ボタン
/// の順に並ぶ。

final _cardDate = DateTime(2026, 8, 4);

ScheduleEntry _entry(String title, {bool completed = false}) => ScheduleEntry(
      schedule: Schedule(
        id: title,
        title: title,
        baseDate: _cardDate,
        repeat: RepeatType.none,
        createdAt: _cardDate,
      ),
      date: _cardDate,
      isCompleted: completed,
    );

DayCard _card({
  required CardVariant variant,
  required int dayOffset,
  List<ScheduleEntry> entries = const [],
  bool acknowledged = false,
}) =>
    DayCard(
      date: _cardDate,
      entries: entries,
      variant: variant,
      acknowledged: acknowledged,
      dayOffset: dayOffset,
    );

Future<void> _pump(WidgetTester tester, DayCard card) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DayCardView(
          card: card,
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
          onAcknowledge: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('カードの名前と日付', () {
    testWidgets('今日のカードは「今日の安心カード」', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.morning,
          dayOffset: 0,
          entries: [_entry('歯医者')],
        ),
      );

      expect(find.text(AppStrings.cardTitleToday), findsOneWidget);
      // 名前とは別の行に、年まで含む日付を出す。
      expect(find.text('2026年8月4日（火）'), findsOneWidget);
    });

    testWidgets('明日のカードは「明日の安心カード」', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.previousNight,
          dayOffset: 1,
          entries: [_entry('歯医者')],
        ),
      );

      expect(find.text(AppStrings.cardTitleTomorrow), findsOneWidget);
    });

    testWidgets('昨日のカードは「昨日の安心カード」', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.past,
          dayOffset: -1,
          entries: [_entry('歯医者', completed: true)],
        ),
      );

      expect(find.text(AppStrings.cardTitleYesterday), findsOneWidget);
    });

    testWidgets('それ以外の日は日付を冠した名前になる', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.future,
          dayOffset: 3,
          entries: [_entry('歯医者')],
        ),
      );

      expect(find.text('8月4日の安心カード'), findsOneWidget);
    });
  });

  group('前日夜のカード', () {
    testWidgets('締めの一文とおやすみなさいボタンが出る', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.previousNight,
          dayOffset: 1,
          entries: [_entry('朝食後に薬')],
        ),
      );

      expect(find.text(AppStrings.cardPreviousNight), findsOneWidget);
      expect(find.text(AppStrings.cardPreviousNightClosing), findsOneWidget);
      expect(find.text(AppStrings.cardGoodNight), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('予定がない日はどの日のことか分かる本文になる', (tester) async {
      // 上下スクロールで日付を行き来する画面のため、本文だけを見ても
      // 取り違えないようにする。（お客様ご指摘 2026/08/17）
      await _pump(
        tester,
        _card(variant: CardVariant.previousNight, dayOffset: 1),
      );

      expect(
        find.text(
          AppStrings.fill(AppStrings.cardEmpty, {'day': AppStrings.cardTomorrow}),
        ),
        findsOneWidget,
      );
    });

    testWidgets('おやすみなさいを押した後は、その言葉がそのまま残る', (tester) async {
      // 別の一文に差し替えると、押した操作と表示がつながらない。
      // （お客様ご指摘 2026/08/17）
      await _pump(
        tester,
        _card(
          variant: CardVariant.previousNight,
          dayOffset: 1,
          entries: [_entry('朝食後に薬')],
          acknowledged: true,
        ),
      );

      expect(find.text(AppStrings.cardGoodNight), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('予定をすべて完了したとき', () {
    // お客様ご指摘 2026/08/17：最後の1つにチェックが付いた時点で、
    // その場に労いの言葉が出る。翌日以降は1行だけ残る。
    testWidgets('その日のうちは2行そろって出る', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.daytime,
          dayOffset: 0,
          entries: [
            _entry('朝食後に薬', completed: true),
            _entry('母さんに電話する', completed: true),
          ],
        ),
      );

      expect(find.text(AppStrings.cardAllDone), findsOneWidget);
      expect(find.text(AppStrings.cardAllDoneRelax), findsOneWidget);
      // 専用のカードや画面には移らず、予定一覧はそのまま残る。
      expect(find.text('朝食後に薬'), findsOneWidget);
    });

    testWidgets('翌日以降は1行だけ残る', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.past,
          dayOffset: -1,
          entries: [_entry('朝食後に薬', completed: true)],
        ),
      );

      expect(find.text(AppStrings.cardAllDone), findsOneWidget);
      expect(find.text(AppStrings.cardAllDoneRelax), findsNothing);
      expect(find.text(AppStrings.cardPast), findsOneWidget);
    });

    testWidgets('やり残しが1つでもあれば出さない', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.daytime,
          dayOffset: 0,
          entries: [
            _entry('朝食後に薬', completed: true),
            _entry('母さんに電話する'),
          ],
        ),
      );

      expect(find.text(AppStrings.cardAllDone), findsNothing);
      expect(find.text(AppStrings.cardAllDoneRelax), findsNothing);
    });

    testWidgets('予定が0件の日には出さない', (tester) async {
      // 何も無い日を「すべてクリアできました」と祝うのは不自然。
      await _pump(
        tester,
        _card(variant: CardVariant.daytime, dayOffset: 0),
      );

      expect(find.text(AppStrings.cardAllDone), findsNothing);
    });
  });

  group('当日のカード', () {
    testWidgets('夜になっても一日を締める専用の表示は出さない', (tester) async {
      // 当日夜のカードは廃止した。夜の通知からは明日のカードを直接開くため、
      // 当日のカードを別の表情に切り替えると二重になる。
      // （お客様ご指摘 2026/08/17）
      await _pump(
        tester,
        _card(
          variant: CardVariant.daytime,
          dayOffset: 0,
          entries: [_entry('歯医者', completed: true)],
        ),
      );

      expect(find.text(AppStrings.cardTitleToday), findsOneWidget);
      expect(find.text('歯医者'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      // 一日を締める見出しや、明日のカードへ促すボタンは持たない。
      expect(find.text(AppStrings.cardOpenCalendar), findsNothing);
    });
  });

  group('カードの並び順', () {
    // 画面イメージ：上に明日、中央に今日、下に昨日。
    const center = 100000;
    final anchor = DateTime(2026, 8, 4);

    test('中央のページが基準日になる', () {
      expect(
        cardDateForIndex(anchor: anchor, centerIndex: center, index: center),
        DateTime(2026, 8, 4),
      );
    });

    test('下のページ（番号が大きい）ほど過去になる', () {
      expect(
        cardDateForIndex(anchor: anchor, centerIndex: center, index: center + 1),
        DateTime(2026, 8, 3),
      );
    });

    test('上のページ（番号が小さい）ほど未来になる', () {
      expect(
        cardDateForIndex(anchor: anchor, centerIndex: center, index: center - 1),
        DateTime(2026, 8, 5),
      );
    });

    test('日付からページ番号を戻せる', () {
      for (final offset in [-30, -1, 0, 1, 30]) {
        final date = anchor.add(Duration(days: offset));
        final index =
            cardIndexForDate(anchor: anchor, centerIndex: center, date: date);
        expect(
          cardDateForIndex(anchor: anchor, centerIndex: center, index: index),
          date,
        );
      }
    });
  });

  group('組み立て時の dayOffset', () {
    test('今日を基準に何日離れているかが入る', () {
      final card = buildDayCard(
        date: DateTime(2026, 8, 6),
        entries: const [],
        now: DateTime(2026, 8, 4, 10, 0),
        morningNotifyTime: const ClockTime(6, 30),
        nightNotifyTime: const ClockTime(21, 30),
      );

      expect(card.dayOffset, 2);
    });
  });
}
