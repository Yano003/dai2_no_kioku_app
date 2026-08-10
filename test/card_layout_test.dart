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
}) =>
    DayCard(
      date: _cardDate,
      entries: entries,
      variant: variant,
      acknowledged: false,
      dayOffset: dayOffset,
    );

Future<void> _pump(
  WidgetTester tester,
  DayCard card, {
  VoidCallback? onOpenTomorrow,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DayCardView(
          card: card,
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
          onAcknowledge: () {},
          onOpenTomorrow: onOpenTomorrow,
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
  });

  group('当日夜のカード', () {
    testWidgets('予定一覧は出さず、明日のカードへ促す', (tester) async {
      // 画面イメージ「当日夜①」：一日を締める表示で、予定一覧は出さない。
      var opened = false;
      await _pump(
        tester,
        _card(
          variant: CardVariant.nightAllDone,
          dayOffset: 0,
          entries: [_entry('歯医者', completed: true)],
        ),
        onOpenTomorrow: () => opened = true,
      );

      expect(find.text(AppStrings.cardTitleNight), findsOneWidget);
      expect(find.text(AppStrings.cardNightAllDone), findsOneWidget);
      expect(find.text(AppStrings.cardNightNext), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      await tester.tap(find.text(AppStrings.cardOpenTomorrow));
      expect(opened, isTrue);
    });

    testWidgets('やり残しがある場合は文言が変わる', (tester) async {
      await _pump(
        tester,
        _card(
          variant: CardVariant.nightRemaining,
          dayOffset: 0,
          entries: [_entry('歯医者')],
        ),
        onOpenTomorrow: () {},
      );

      expect(find.text(AppStrings.cardNightRemaining), findsOneWidget);
      expect(find.text(AppStrings.cardNightAllDone), findsNothing);
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
