import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../domain/parser/parsed_schedule.dart';

/// アプリの設定値。（要件定義書 4.4 / 4.8 / 6.2）
class AppSettings {
  const AppSettings({
    required this.wakeTime,
    required this.sleepTime,
    required this.morningNotifyTime,
    required this.nightNotifyTime,
    required this.onboardingCompleted,
    required this.notifyTimeConfirmed,
  });

  /// 起床のおおよその時刻。初回設定で一度だけ伺う。（要件定義書 6.2）
  final ClockTime wakeTime;

  /// 就寝のおおよその時刻。
  final ClockTime sleepTime;

  /// 当日朝の通知時刻。既定は起床の30分前。
  final ClockTime morningNotifyTime;

  /// 前日夜の通知時刻。既定は就寝の30分前。
  final ClockTime nightNotifyTime;

  /// 初回起動案内（S-01）を完了したか。
  final bool onboardingCompleted;

  /// 通知時刻（S-04）を利用者が一度確認したか。
  ///
  /// 「一度設定した時刻は以降の登録にも引き継がれ、毎回設定する必要はない」
  /// （要件定義書 4.4）を満たすため、初回の登録後にだけ S-04 を挟む判断に使う。
  final bool notifyTimeConfirmed;

  /// 起床・就寝時刻から通知時刻の初期値を逆算する。（要件定義書 6.2）
  static ClockTime morningNotifyFor(ClockTime wakeTime) =>
      wakeTime.subtract(AppConfig.notificationOffsetBeforeWake);

  static ClockTime nightNotifyFor(ClockTime sleepTime) =>
      sleepTime.subtract(AppConfig.notificationOffsetBeforeSleep);

  AppSettings copyWith({
    ClockTime? wakeTime,
    ClockTime? sleepTime,
    ClockTime? morningNotifyTime,
    ClockTime? nightNotifyTime,
    bool? onboardingCompleted,
    bool? notifyTimeConfirmed,
  }) {
    return AppSettings(
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      morningNotifyTime: morningNotifyTime ?? this.morningNotifyTime,
      nightNotifyTime: nightNotifyTime ?? this.nightNotifyTime,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      notifyTimeConfirmed: notifyTimeConfirmed ?? this.notifyTimeConfirmed,
    );
  }

  static AppSettings get defaults {
    const wake = AppConfig.defaultWakeTime;
    const sleep = AppConfig.defaultSleepTime;
    return AppSettings(
      wakeTime: wake,
      sleepTime: sleep,
      morningNotifyTime: morningNotifyFor(wake),
      nightNotifyTime: nightNotifyFor(sleep),
      onboardingCompleted: false,
      notifyTimeConfirmed: false,
    );
  }
}

/// 設定値の永続化。端末内のみ。（要件定義書 7.1）
class SettingsRepository {
  static const _keyWake = 'wake_time_minutes';
  static const _keySleep = 'sleep_time_minutes';
  static const _keyMorningNotify = 'morning_notify_minutes';
  static const _keyNightNotify = 'night_notify_minutes';
  static const _keyOnboarding = 'onboarding_completed';
  static const _keyNotifyConfirmed = 'notify_time_confirmed';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = AppSettings.defaults;

    ClockTime read(String key, ClockTime fallback) {
      final minutes = prefs.getInt(key);
      if (minutes == null) return fallback;
      return ClockTime(minutes ~/ 60, minutes % 60);
    }

    return AppSettings(
      wakeTime: read(_keyWake, defaults.wakeTime),
      sleepTime: read(_keySleep, defaults.sleepTime),
      morningNotifyTime: read(_keyMorningNotify, defaults.morningNotifyTime),
      nightNotifyTime: read(_keyNightNotify, defaults.nightNotifyTime),
      onboardingCompleted:
          prefs.getBool(_keyOnboarding) ?? defaults.onboardingCompleted,
      notifyTimeConfirmed:
          prefs.getBool(_keyNotifyConfirmed) ?? defaults.notifyTimeConfirmed,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWake, settings.wakeTime.totalMinutes);
    await prefs.setInt(_keySleep, settings.sleepTime.totalMinutes);
    await prefs.setInt(
      _keyMorningNotify,
      settings.morningNotifyTime.totalMinutes,
    );
    await prefs.setInt(_keyNightNotify, settings.nightNotifyTime.totalMinutes);
    await prefs.setBool(_keyOnboarding, settings.onboardingCompleted);
    await prefs.setBool(_keyNotifyConfirmed, settings.notifyTimeConfirmed);
  }
}
