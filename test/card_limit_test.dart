import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/data/schedule_repository.dart';
import 'package:dai2_no_kioku/domain/parser/parsed_schedule.dart';
import 'package:dai2_no_kioku/features/confirm/confirm_screen.dart';
import 'package:dai2_no_kioku/providers.dart';
import 'package:dai2_no_kioku/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1日あたりの上限（要件定義書 第2.0版 2.2）の検証。
///
/// 上限値は [AppConfig.maxSchedulesPerDay] の1箇所だけで定義されている。
/// テストでも数値を直書きせず、この定数を参照する。
class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository({required this.remaining});

  /// 日付ごとの残り登録可能件数。
  final Map<DateTime, int> remaining;

  final List<String> inserted = [];

  @override
  Future<Map<DateTime, int>> remainingCapacityForDates(
    Iterable<DateTime> dates,
  ) async =>
      {for (final date in dates) date: remaining[date] ?? 0};

  @override
  Future<int> remainingCapacityOn(DateTime date) async => remaining[date] ?? 0;

  @override
  Future<Schedule> insert({
    required String title,
    required DateTime baseDate,
    ClockTime? time,
    RepeatType repeat = RepeatType.none,
    int? weekday,
  }) async {
    inserted.add(title);
    return Schedule(
      id: title,
      title: title,
      baseDate: baseDate,
      time: time,
      repeat: repeat,
      weekday: weekday,
      createdAt: DateTime(2026, 8, 4),
    );
  }

  @override
  Future<Map<DateTime, List<ScheduleEntry>>> entriesForRange(
    DateTime from,
    DateTime to,
  ) async =>
      {};

  @override
  Future<Set<DateTime>> acknowledgedDates(DateTime from, DateTime to) async =>
      {};
}

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> rescheduleAll({DateTime? now}) async {}

  @override
  Future<bool> areNotificationsEnabled() async => true;
}

final _targetDate = DateTime(2026, 8, 5);

ParsedSchedule _item(String title) => ParsedSchedule(
      title: title,
      sourceText: title,
      date: _targetDate,
      dateWasSpecified: true,
    );

Finder get _registerButton =>
    find.widgetWithText(FilledButton, AppStrings.confirmRegister);

void main() {
  Future<_FakeScheduleRepository> pumpConfirm(
    WidgetTester tester, {
    required int remaining,
    required List<ParsedSchedule> items,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        _FakeScheduleRepository(remaining: {_targetDate: remaining});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: MaterialApp(home: ConfirmScreen(items: items)),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('上限に達している日には登録できない', (tester) async {
    final repository = await pumpConfirm(
      tester,
      remaining: 0,
      items: [_item('歯医者')],
    );

    // 突き放さず、上限の理由と別日なら登録できることを伝える。
    expect(find.textContaining('別の日でしたら登録できます'), findsOneWidget);
    expect(find.text(AppStrings.confirmLimitBadge), findsOneWidget);

    expect(tester.widget<FilledButton>(_registerButton).onPressed, isNull);
    expect(repository.inserted, isEmpty);
  });

  testWidgets('同じ日にまとめて登録するときは合計で判定する', (tester) async {
    // 残り2件のところへ3件まとめて登録しようとした場合。
    final repository = await pumpConfirm(
      tester,
      remaining: 2,
      items: [_item('歯医者'), _item('薬'), _item('買い物')],
    );

    expect(tester.widget<FilledButton>(_registerButton).onPressed, isNull);
    expect(repository.inserted, isEmpty);
  });

  testWidgets('残り件数ちょうどなら登録できる', (tester) async {
    final repository = await pumpConfirm(
      tester,
      remaining: 2,
      items: [_item('歯医者'), _item('薬')],
    );

    expect(tester.widget<FilledButton>(_registerButton).onPressed, isNotNull);

    await tester.tap(_registerButton);
    await tester.pumpAndSettle();

    expect(repository.inserted, ['歯医者', '薬']);
  });

  testWidgets('空きがあるときは残り件数を伝える', (tester) async {
    await pumpConfirm(tester, remaining: 3, items: [_item('歯医者')]);

    expect(
      find.text(AppStrings.withCount(AppStrings.confirmRemaining, 3)),
      findsOneWidget,
    );
  });

  test('上限値は1箇所で定義されている', () {
    // 将来フェーズ2で変更しやすい構造とする。（要件定義書 2.2）
    expect(AppConfig.maxSchedulesPerDay, 5);
  });
}
