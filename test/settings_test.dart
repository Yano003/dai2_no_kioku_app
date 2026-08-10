import 'package:dai2_no_kioku/core/clock_time.dart';
import 'package:dai2_no_kioku/data/settings_repository.dart';
import 'package:dai2_no_kioku/providers.dart';
import 'package:dai2_no_kioku/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  int rescheduleCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> rescheduleAll({DateTime? now}) async => rescheduleCount++;
}

void main() {
  // 要件定義書 6.2：初回設定で伺った起床・就寝の時刻から30分前を
  // 初期値として、固定時刻の通知を設定する。
  group('通知時刻の逆算', () {
    test('就寝の30分前が前日夜の通知時刻になる', () {
      expect(
        AppSettings.nightNotifyFor(const ClockTime(22, 0)),
        const ClockTime(21, 30),
      );
      expect(
        AppSettings.nightNotifyFor(const ClockTime(23, 0)),
        const ClockTime(22, 30),
      );
    });

    test('起床の30分前が当日朝の通知時刻になる', () {
      expect(
        AppSettings.morningNotifyFor(const ClockTime(7, 0)),
        const ClockTime(6, 30),
      );
      expect(
        AppSettings.morningNotifyFor(const ClockTime(5, 15)),
        const ClockTime(4, 45),
      );
    });

    test('0時をまたぐ場合は前日の時刻へ巻き戻る', () {
      // 0時15分に就寝する人の通知は、前日の23時45分になる。
      expect(
        AppSettings.nightNotifyFor(const ClockTime(0, 15)),
        const ClockTime(23, 45),
      );
      expect(
        AppSettings.morningNotifyFor(const ClockTime(0, 10)),
        const ClockTime(23, 40),
      );
    });
  });

  group('設定の保存と読み込み', () {
    test('保存した値がそのまま読み戻せる', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();

      const settings = AppSettings(
        wakeTime: ClockTime(5, 30),
        sleepTime: ClockTime(23, 15),
        morningNotifyTime: ClockTime(5, 0),
        nightNotifyTime: ClockTime(22, 45),
        onboardingCompleted: true,
        notifyTimeConfirmed: true,
      );

      await repository.save(settings);
      final loaded = await repository.load();

      expect(loaded.wakeTime, const ClockTime(5, 30));
      expect(loaded.sleepTime, const ClockTime(23, 15));
      expect(loaded.morningNotifyTime, const ClockTime(5, 0));
      expect(loaded.nightNotifyTime, const ClockTime(22, 45));
      expect(loaded.onboardingCompleted, isTrue);
      expect(loaded.notifyTimeConfirmed, isTrue);
    });

    test('未設定のときは既定値を返す', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await SettingsRepository().load();

      // 初回起動案内が未完了であること。これが起動時の分岐に使われる。
      expect(loaded.onboardingCompleted, isFalse);
      // 初回登録時に S-04 を挟むこと。（要件定義書 4.4）
      expect(loaded.notifyTimeConfirmed, isFalse);
      expect(loaded.nightNotifyTime, const ClockTime(21, 30));
      expect(loaded.morningNotifyTime, const ClockTime(6, 30));
    });
  });

  // S-08 設定画面：起床・就寝を変えると通知時刻も追随する。（要件定義書 4.8 / 6.2）
  group('S-08 いつもの時刻の変更', () {
    test('起床・就寝を変えると通知時刻も30分前に合わせて変わる', () async {
      SharedPreferences.setMockInitialValues({});
      final notifications = _FakeNotificationService();

      final container = ProviderContainer.test(
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
        ],
      );

      await container.read(settingsProvider.future);
      await container.read(settingsProvider.notifier).saveSleepSchedule(
            sleepTime: const ClockTime(23, 0),
            wakeTime: const ClockTime(6, 0),
          );

      final saved = await SettingsRepository().load();
      expect(saved.sleepTime, const ClockTime(23, 0));
      expect(saved.wakeTime, const ClockTime(6, 0));
      expect(saved.nightNotifyTime, const ClockTime(22, 30));
      expect(saved.morningNotifyTime, const ClockTime(5, 30));

      // 通知時刻が変わったので予約を作り直していること。
      expect(notifications.rescheduleCount, greaterThan(0));
    });

    test('通知時刻だけを変えても、いつもの時刻は動かない', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
      );

      final current = await container.read(settingsProvider.future);
      await container.read(settingsProvider.notifier).save(
            current.copyWith(
              nightNotifyTime: const ClockTime(20, 0),
              notifyTimeConfirmed: true,
            ),
          );

      final saved = await SettingsRepository().load();
      expect(saved.nightNotifyTime, const ClockTime(20, 0));
      // 就寝時刻は既定の22:00 のまま。
      expect(saved.sleepTime, const ClockTime(22, 0));
      expect(saved.notifyTimeConfirmed, isTrue);
    });
  });
}
