import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/core/clock_time.dart';
import 'package:dai2_no_kioku/data/settings_repository.dart';
import 'package:dai2_no_kioku/features/onboarding/onboarding_screen.dart';
import 'package:dai2_no_kioku/providers.dart';
import 'package:dai2_no_kioku/services/notification_service.dart';
import 'package:dai2_no_kioku/services/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末の機能に触れずに導線だけを検証するための差し替え。
class _FakeSpeechService extends SpeechService {
  bool initializeCalled = false;

  @override
  Future<bool> initialize({void Function(String error)? onError}) async {
    initializeCalled = true;
    return true;
  }
}

class _FakeNotificationService extends NotificationService {
  bool permissionRequested = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return true;
  }

  @override
  Future<void> rescheduleAll({DateTime? now}) async {}

  @override
  Future<bool> areNotificationsEnabled() async => true;
}

void main() {
  late _FakeSpeechService speech;
  late _FakeNotificationService notifications;

  Future<void> pumpOnboarding(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    speech = _FakeSpeechService();
    notifications = _FakeNotificationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechServiceProvider.overrideWithValue(speech),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('許可を1つずつ順に取得し、最後まで進むと完了が記録される', (tester) async {
    await pumpOnboarding(tester);

    // 1画面目：ようこそ
    expect(find.text(AppStrings.onboardingWelcomeTitle), findsOneWidget);
    await tapLabel(tester, AppStrings.onboardingNext);

    // 2画面目：声（マイク・文字起こし）。許可の前に理由を説明していること。
    expect(find.text(AppStrings.onboardingMicTitle), findsOneWidget);
    expect(find.textContaining('マイクを使います'), findsOneWidget);
    await tapLabel(tester, AppStrings.onboardingAllow);
    expect(speech.initializeCalled, isTrue);

    // 3画面目：お知らせ
    expect(find.text(AppStrings.onboardingNotificationTitle), findsOneWidget);
    await tapLabel(tester, AppStrings.onboardingAllow);
    expect(notifications.permissionRequested, isTrue);

    // 4画面目：就寝時刻（要件定義書 6.2）
    expect(find.text(AppStrings.onboardingSleepQuestion), findsOneWidget);
    await tapLabel(tester, AppStrings.onboardingNext);

    // 5画面目：起床時刻
    expect(find.text(AppStrings.onboardingWakeQuestion), findsOneWidget);
    await tapLabel(tester, AppStrings.onboardingStart);

    final saved = await SettingsRepository().load();
    expect(saved.onboardingCompleted, isTrue);
    // 既定の就寝22:00／起床07:00 から30分前が逆算されていること。
    expect(saved.nightNotifyTime, const ClockTime(21, 30));
    expect(saved.morningNotifyTime, const ClockTime(6, 30));
  });

  testWidgets('「あとで」で許可を拒んでも先へ進める', (tester) async {
    // 許可が拒否された場合も操作は続行できること。（要件定義書 4.1）
    await pumpOnboarding(tester);

    await tapLabel(tester, AppStrings.onboardingNext);
    await tapLabel(tester, AppStrings.onboardingSkip);
    expect(speech.initializeCalled, isFalse);

    expect(find.text(AppStrings.onboardingNotificationTitle), findsOneWidget);
    await tapLabel(tester, AppStrings.onboardingSkip);
    expect(notifications.permissionRequested, isFalse);

    // 許可を1つも与えなくても、最後まで到達できる。
    expect(find.text(AppStrings.onboardingSleepQuestion), findsOneWidget);
    await tapLabel(tester, AppStrings.onboardingNext);
    await tapLabel(tester, AppStrings.onboardingStart);

    final saved = await SettingsRepository().load();
    expect(saved.onboardingCompleted, isTrue);
  });

  testWidgets('起床・就寝の時刻を選び直すと通知時刻に反映される', (tester) async {
    await pumpOnboarding(tester);

    await tapLabel(tester, AppStrings.onboardingNext);
    await tapLabel(tester, AppStrings.onboardingSkip);
    await tapLabel(tester, AppStrings.onboardingSkip);

    // 就寝時刻の初期表示は既定値の22:00。
    expect(find.text('22:00'), findsOneWidget);
    expect(find.text(AppStrings.onboardingTapToChange), findsOneWidget);

    await tapLabel(tester, AppStrings.onboardingNext);
    // 起床時刻の初期表示は既定値の07:00。
    expect(find.text('07:00'), findsOneWidget);
  });
}
