import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/core/clock_time.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/data/schedule_repository.dart';
import 'package:dai2_no_kioku/features/edit/edit_schedule_screen.dart';
import 'package:dai2_no_kioku/providers.dart';
import 'package:dai2_no_kioku/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// データベースに触れずに画面の振る舞いだけを検証するための差し替え。
class _FakeScheduleRepository extends ScheduleRepository {
  Schedule? updated;
  String? deletedId;

  @override
  Future<void> update(Schedule schedule) async => updated = schedule;

  @override
  Future<void> delete(String scheduleId) async => deletedId = scheduleId;

  @override
  Future<Map<DateTime, List<ScheduleEntry>>> entriesForRange(
    DateTime from,
    DateTime to,
  ) async =>
      {};

}

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> rescheduleAll({DateTime? now}) async {}
}

final _schedule = Schedule(
  id: 'schedule-1',
  title: '歯医者',
  baseDate: DateTime(2026, 8, 5),
  time: const ClockTime(15, 0),
  repeat: RepeatType.none,
  createdAt: DateTime(2026, 8, 4),
);

void main() {
  late _FakeScheduleRepository repository;

  Future<void> pumpEditScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeScheduleRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: MaterialApp(home: EditScheduleScreen(schedule: _schedule)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('登録済みの内容が初期表示される', (tester) async {
    await pumpEditScreen(tester);

    expect(find.text('歯医者'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text(AppStrings.editRepeatNone), findsOneWidget);
  });

  testWidgets('予定名を変えて保存できる', (tester) async {
    await pumpEditScreen(tester);

    await tester.enterText(find.byType(TextField), '内科');
    await tester.tap(find.text(AppStrings.editSave));
    await tester.pumpAndSettle();

    expect(repository.updated?.title, '内科');
    expect(repository.updated?.id, 'schedule-1');
  });

  testWidgets('予定名が空だと保存できない', (tester) async {
    await pumpEditScreen(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.editSave),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('繰り返しを毎日に変えて保存できる', (tester) async {
    await pumpEditScreen(tester);

    await tester.tap(find.text(AppStrings.editRepeatDaily));
    await tester.pumpAndSettle();

    // 変更が今後すべてに及ぶことを画面上で伝えていること。
    expect(find.text(AppStrings.editRepeatScopeNote), findsOneWidget);

    await tester.tap(find.text(AppStrings.editSave));
    await tester.pumpAndSettle();

    expect(repository.updated?.repeat, RepeatType.daily);
  });

  testWidgets('時刻を消すと終日扱いになる', (tester) async {
    await pumpEditScreen(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.confirmAllDay), findsOneWidget);

    await tester.tap(find.text(AppStrings.editSave));
    await tester.pumpAndSettle();

    expect(repository.updated?.time, isNull);
  });

  testWidgets('削除は確認してから実行される', (tester) async {
    await pumpEditScreen(tester);

    // 画面上の削除ボタンと、確認ダイアログの実行ボタンは同じ文言のため、
    // ウィジェットの型で区別する。
    final screenDeleteButton =
        find.widgetWithText(TextButton, AppStrings.editDelete);
    final dialogConfirmButton =
        find.widgetWithText(FilledButton, AppStrings.editDeleteConfirmYes);

    await tester.tap(screenDeleteButton);
    await tester.pumpAndSettle();

    // いきなり消えず、必ず確認を挟む。
    expect(find.text(AppStrings.editDeleteConfirm), findsOneWidget);
    expect(repository.deletedId, isNull);

    // 「やめる」を選べば削除されない。
    await tester.tap(find.text(AppStrings.editDeleteConfirmNo));
    await tester.pumpAndSettle();
    expect(repository.deletedId, isNull);

    await tester.tap(screenDeleteButton);
    await tester.pumpAndSettle();
    await tester.tap(dialogConfirmButton);
    await tester.pumpAndSettle();

    expect(repository.deletedId, 'schedule-1');
  });
}
