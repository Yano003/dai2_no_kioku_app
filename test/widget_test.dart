import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/core/clock_time.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/domain/card/day_card.dart';
import 'package:dai2_no_kioku/features/card/day_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 安心カードの描画テスト。
///
/// 端末やデータベースに依存しないよう、組み立て済みの [DayCard] を
/// 直接渡して描画する。
Widget _wrap(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: child),
    ),
  );
}

ScheduleEntry _entry(String title, {bool completed = false, ClockTime? time}) {
  final date = DateTime(2026, 8, 4);
  return ScheduleEntry(
    schedule: Schedule(
      id: title,
      title: title,
      baseDate: date,
      time: time,
      repeat: RepeatType.none,
      createdAt: date,
    ),
    date: date,
    isCompleted: completed,
  );
}

DayCard _card({
  required CardVariant variant,
  List<ScheduleEntry> entries = const [],
  int dayOffset = 0,
}) {
  return DayCard(
    date: DateTime(2026, 8, 4),
    entries: entries,
    variant: variant,
    dayOffset: dayOffset,
  );
}

void main() {
  testWidgets('当日朝のカードに件数と結びの言葉が出る', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: _card(
            variant: CardVariant.morning,
            entries: [_entry('歯医者'), _entry('薬を飲む')],
          ),
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
        ),
      ),
    );

    // 文言は差し替え前提のため、リテラルではなく定数を参照して比較する。
    expect(
      find.text(AppStrings.withCount(AppStrings.cardMorning, 2)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.cardHaveANiceDay), findsOneWidget);
    expect(find.text('歯医者'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('予定のない日は穏やかな表現になる', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: _card(variant: CardVariant.daytime),
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
        ),
      ),
    );

    // どの日のカードかが本文だけで分かるようにする。（お客様ご指摘 2026/08/17）
    expect(
      find.text(
        AppStrings.fill(AppStrings.cardEmpty, {'day': AppStrings.cardToday}),
      ),
      findsOneWidget,
    );
  });

  testWidgets('当日日中のカードにボタンを置かない', (tester) async {
    // 「確認しました」ボタンは第2.0版で廃止。実質的にアプリを閉じるだけの
    // 操作のため不要と判断された。（要件定義書 4.5）
    // 完了チェックは各予定のチェックボックスで行う。
    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: _card(
            variant: CardVariant.daytime,
            entries: [_entry('歯医者')],
          ),
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('カードに表示する予定は最大5件', (tester) async {
    // 要件定義書 2.2 / 4.5：1枚のカードに表示する予定は最大5件。
    final entries = [
      for (var i = 1; i <= 7; i++) _entry('予定$i'),
    ];
    final card = buildDayCard(
      date: DateTime(2026, 8, 4),
      entries: entries,
      now: DateTime(2026, 8, 4, 13, 0),
      morningNotifyTime: const ClockTime(6, 30),
      nightNotifyTime: const ClockTime(21, 30),
    );

    expect(card.entries, hasLength(5));
    expect(card.hiddenCount, 2);

    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: card,
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
        ),
      ),
    );

    expect(find.byType(Checkbox), findsNWidgets(5));
    expect(find.text('予定6'), findsNothing);
  });

  testWidgets('未来のカードではチェックできない', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: _card(
            variant: CardVariant.future,
            entries: [_entry('歯医者')],
          ),
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
        ),
      ),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.onChanged, isNull);
  });

  testWidgets('チェックすると通知される', (tester) async {
    ScheduleEntry? toggled;
    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: _card(
            variant: CardVariant.daytime,
            entries: [_entry('歯医者')],
          ),
          onToggleEntry: (entry) => toggled = entry,
          onEditEntry: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    expect(toggled?.title, '歯医者');
  });

  testWidgets('修正ボタンから S-07 を開ける', (tester) async {
    // 完了チェックと修正は別々の操作にする。長押しに割り当てると
    // 対象利用者には気づけないため、独立したボタンとして置いている。
    ScheduleEntry? edited;
    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: _card(
            variant: CardVariant.daytime,
            entries: [_entry('歯医者')],
          ),
          onToggleEntry: (_) {},
          onEditEntry: (entry) => edited = entry,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    expect(edited?.title, '歯医者');
  });

  testWidgets('OSの文字サイズを最大にしてもレイアウトが破綻しない', (tester) async {
    // 「文字を大きくする」のではなく「文字を大きくできる」設計であること。
    // （要件定義書 8章 補足）
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        DayCardView(
          card: _card(
            variant: CardVariant.morning,
            entries: [
              _entry('歯医者', time: const ClockTime(15, 0)),
              _entry('薬を飲む'),
              _entry('牛乳を買う'),
            ],
          ),
          onToggleEntry: (_) {},
          onEditEntry: (_) {},
        ),
        textScale: 2.0,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
