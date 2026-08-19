import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/core/date_key.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/data/schedule_repository.dart';
import 'package:dai2_no_kioku/features/card/card_screen.dart';
import 'package:dai2_no_kioku/features/input/input_screen.dart';
import 'package:dai2_no_kioku/main.dart';
import 'package:dai2_no_kioku/providers.dart';
import 'package:dai2_no_kioku/services/notification_service.dart';
import 'package:dai2_no_kioku/services/speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 通知をタップしたときに、どの日のカードから始まるかの検証。
///
/// お客様ご指摘 2026/08/17：前日夜の通知をタップすると「今日の安心カード」が
/// 開いてしまっていた。通知が運ぶ日付（翌日）は正しかったため、原因は
/// 予約側ではなく起動側にあった。この経路にはテストが1つも無く、
/// 予約側のテストが通っていても不具合が残り続けたため、ここで固定する。
class _FakeSpeechService extends SpeechService {
  @override
  Future<bool> initialize({void Function(String error)? onError}) async => false;
}

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> rescheduleAll({DateTime? now}) async {}

  @override
  Future<bool> areNotificationsEnabled() async => true;
}

class _FakeScheduleRepository extends ScheduleRepository {
  @override
  Future<Map<DateTime, List<ScheduleEntry>>> entriesForRange(
    DateTime from,
    DateTime to,
  ) async =>
      {for (final date in dateRange(from, to)) date: const []};

  @override
  Future<Set<DateTime>> acknowledgedDates(DateTime from, DateTime to) async =>
      const {};
}

void main() {
  late _FakeNotificationService notifications;

  /// 初回起動案内は済んでいる状態から始める。
  ///
  /// [pendingCardDate] は、アプリが終了している状態から通知で起動された
  /// ことを表す。通知サービスが起動時に受け取る日付にあたる。
  Future<void> pumpApp(WidgetTester tester, {DateTime? pendingCardDate}) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    notifications = _FakeNotificationService()
      ..pendingCardDate = pendingCardDate;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
          speechServiceProvider.overrideWithValue(_FakeSpeechService()),
          scheduleRepositoryProvider
              .overrideWithValue(_FakeScheduleRepository()),
        ],
        child: const Dai2NoKiokuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  DateTime openedDate(WidgetTester tester) =>
      tester.widget<CardScreen>(find.byType(CardScreen)).initialDate!;

  final tomorrow = dateOnly(DateTime.now().add(const Duration(days: 1)));

  testWidgets('通知から起動すると、通知が指す日のカードから始まる', (tester) async {
    // 前日夜の通知が運ぶのは翌日の日付。当日のカードを挟まずに開く。
    await pumpApp(tester, pendingCardDate: tomorrow);

    expect(find.byType(CardScreen), findsOneWidget);
    expect(openedDate(tester), tomorrow);
    expect(find.text(AppStrings.cardTitleTomorrow), findsWidgets);
  });

  testWidgets('通知以外の通常の起動は音声入力画面から始まる', (tester) async {
    await pumpApp(tester);

    expect(find.byType(InputScreen), findsOneWidget);
    expect(find.byType(CardScreen), findsNothing);
  });

  testWidgets('アプリを開いている間のタップでも、その日のカードへ移る', (tester) async {
    await pumpApp(tester);
    expect(find.byType(InputScreen), findsOneWidget);

    // 通知サービスから届くタップ。UI 側が差し込んだコールバックが呼ばれる。
    notifications.onOpenCard!(tomorrow);
    await tester.pumpAndSettle();

    expect(openedDate(tester), tomorrow);
  });

  testWidgets('起動直後に届いたタップも取りこぼさない', (tester) async {
    // Navigator がまだ構築されていない時点で呼ばれると、push は黙って
    // 捨てられる。日付を状態として持つことで、表示の起点をカードへ切り替える。
    await pumpApp(tester);

    notifications.onOpenCard!(tomorrow);
    await tester.pumpAndSettle();

    // 続けて別の日を開いても、前の日付のまま使い回されない。
    final dayAfter = tomorrow.add(const Duration(days: 1));
    notifications.onOpenCard!(dayAfter);
    await tester.pumpAndSettle();

    expect(openedDate(tester), dayAfter);
  });

  testWidgets('取り出した日付は消え、二度目は通常の起動になる', (tester) async {
    await pumpApp(tester, pendingCardDate: tomorrow);

    expect(notifications.pendingCardDate, isNull);
    expect(notifications.consumePendingCardDate(), isNull);
  });
}
