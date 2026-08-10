import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/data/schedule_repository.dart';
import 'package:dai2_no_kioku/features/calendar/calendar_screen.dart';
import 'package:dai2_no_kioku/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 予定件数だけを返す差し替え。データベースには触れない。
class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository(this.counts);

  final Map<DateTime, int> counts;

  /// 実際に問い合わせられた期間。月の切り替えで読み直しているかの確認に使う。
  final List<(DateTime, DateTime)> requestedRanges = [];

  @override
  Future<Map<DateTime, int>> countsForRange(DateTime from, DateTime to) async {
    requestedRanges.add((from, to));
    return counts;
  }

  @override
  Future<Map<DateTime, List<ScheduleEntry>>> entriesForRange(
    DateTime from,
    DateTime to,
  ) async =>
      {};
}

void main() {
  // 2026年8月は土曜始まり・31日。月初の空きマスの計算を検証するのに都合がよい。
  final august = DateTime(2026, 8, 4);

  Future<_FakeScheduleRepository> pumpCalendar(
    WidgetTester tester, {
    Map<DateTime, int> counts = const {},
    DateTime? initialDate,
  }) async {
    final repository = _FakeScheduleRepository(counts);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: CalendarScreen(initialDate: initialDate ?? august),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('開いた月が見出しに出る', (tester) async {
    await pumpCalendar(tester);
    expect(find.text('2026年8月'), findsOneWidget);
  });

  testWidgets('その月の日数ぶんのマスが並ぶ', (tester) async {
    await pumpCalendar(tester);

    // 8月は31日まで。1日と31日が存在し、32日は存在しない。
    expect(find.text('1'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('32'), findsNothing);
  });

  testWidgets('曜日の見出しが日曜始まりで並ぶ', (tester) async {
    await pumpCalendar(tester);

    for (final label in AppStrings.calendarWeekdayHeaders) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('予定がある日には印が表示される', (tester) async {
    // 要件定義書 4.6：予定がある日には印を表示する。
    await pumpCalendar(
      tester,
      counts: {
        DateTime(2026, 8, 5): 2,
        DateTime(2026, 8, 12): 1,
      },
    );

    expect(find.byKey(const ValueKey('mark-2026-08-05')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark-2026-08-12')), findsOneWidget);

    // 予定のない日には印を付けない。マス自体は存在する。
    expect(find.byKey(const ValueKey('mark-2026-08-06')), findsNothing);
    expect(find.byKey(const ValueKey('day-2026-08-06')), findsOneWidget);
  });

  testWidgets('日付を選ぶとその日付を返して閉じる', (tester) async {
    // 選んだ日付のカードへ移動するのは呼び出し元（S-05）の責務。
    final repository = _FakeScheduleRepository(const {});
    DateTime? returned;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scheduleRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  returned = await Navigator.of(context).push<DateTime>(
                    MaterialPageRoute<DateTime>(
                      builder: (_) => CalendarScreen(initialDate: august),
                    ),
                  );
                },
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('day-2026-08-20')));
    await tester.pumpAndSettle();

    expect(returned, DateTime(2026, 8, 20));
  });

  testWidgets('月を切り替えると件数を読み直す', (tester) async {
    final repository = await pumpCalendar(tester);
    expect(repository.requestedRanges, hasLength(1));

    await tester.tap(find.byTooltip(AppStrings.calendarNextMonth));
    await tester.pumpAndSettle();

    expect(find.text('2026年9月'), findsOneWidget);
    expect(repository.requestedRanges, hasLength(2));
    // 9月の1日から30日までを問い合わせていること。
    expect(repository.requestedRanges.last.$1, DateTime(2026, 9, 1));
    expect(repository.requestedRanges.last.$2, DateTime(2026, 9, 30));

    await tester.tap(find.byTooltip(AppStrings.calendarPreviousMonth));
    await tester.pumpAndSettle();
    expect(find.text('2026年8月'), findsOneWidget);
  });

  testWidgets('年をまたぐ月の切り替えができる', (tester) async {
    await pumpCalendar(tester, initialDate: DateTime(2026, 12, 15));

    await tester.tap(find.byTooltip(AppStrings.calendarNextMonth));
    await tester.pumpAndSettle();

    expect(find.text('2027年1月'), findsOneWidget);
  });
}
