import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_config.dart';
import '../core/date_key.dart';
import '../data/schedule_repository.dart';
import '../data/settings_repository.dart';
import 'notification_planner.dart';

/// 通知の初期化と予約を担う。
///
/// ■ 技術的制約（要件定義書 6.3）
/// - 通知は一文で届く。チェックボックス付きのカードを通知内には出せない。
/// - Android は端末の省電力機能により、設定時刻から遅れることがある。
///   `AndroidScheduleMode.exactAllowWhileIdle` で最大限の精度を狙うが、
///   100%の保証はできない。
/// - Android は端末を再起動すると予約済みの通知が消えるため、
///   AndroidManifest.xml に BOOT_COMPLETED の受信設定が必要
///   （flutter_local_notifications の ScheduledNotificationBootReceiver）。
class NotificationService {
  NotificationService({
    ScheduleRepository? scheduleRepository,
    SettingsRepository? settingsRepository,
  })  : _schedules = scheduleRepository ?? ScheduleRepository(),
        _settings = settingsRepository ?? SettingsRepository();

  final ScheduleRepository _schedules;
  final SettingsRepository _settings;

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'dai2_no_kioku_daily';
  static const _channelName = 'お知らせ';
  static const _channelDescription = '前の日の夜と当日の朝に、予定をお知らせします。';

  bool _initialized = false;

  /// 通知タップで開くカードの日付。アプリ起動時に受け取る。
  DateTime? pendingCardDate;

  /// 通知タップ時に呼ばれるコールバック。UI 側から差し込む。
  void Function(DateTime cardDate)? onOpenCard;

  // ---------------------------------------------------------------------------
  // 初期化
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    await _configureTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      // 許可要求は S-01（初回起動案内）で理由を説明してから明示的に行うため、
      // 初期化時には要求しない。（要件定義書 4.1）
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    // アプリが終了している状態で通知をタップして起動された場合。
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      pendingCardDate = _cardDateFromPayload(payload);
    }

    _initialized = true;
  }

  Future<void> _configureTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      // タイムゾーンを特定できない場合も通知自体は動かす必要があるため、
      // 日本標準時にフォールバックする。
      debugPrint('タイムゾーンの取得に失敗しました: $error');
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    }
  }

  void _handleResponse(NotificationResponse response) {
    final date = _cardDateFromPayload(response.payload);
    if (date == null) return;
    pendingCardDate = date;
    onOpenCard?.call(date);
  }

  static DateTime? _cardDateFromPayload(String? payload) {
    if (payload == null || !payload.startsWith('card:')) return null;
    try {
      return fromDateKey(payload.substring('card:'.length));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 許可
  // ---------------------------------------------------------------------------

  /// 通知の利用許可を求める。（要件定義書 4.1）
  ///
  /// Android 13 以降は通知にも実行時の許可が必要。
  /// 拒否された場合も操作は続行できる。
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;

      // 時刻ちょうどに届けるための許可。Android 14 以降は既定で許可されない。
      // 拒否されても通知自体は届く（遅延する可能性がある）ため、結果は問わない。
      await android?.requestExactAlarmsPermission();

      return granted;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true, badge: true) ??
          false;
    }

    return false;
  }

  /// 通知が有効になっているか。（要件定義書 4.8 各種利用許可の状態確認）
  ///
  /// 拒否されていても機能自体は動くため、画面上の注意書きの出し分けに使う。
  Future<bool> areNotificationsEnabled() async {
    await initialize();

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final options = await ios?.checkPermissions();
      return options?.isEnabled ?? false;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 予約
  // ---------------------------------------------------------------------------

  /// 通知を予約し直す。
  ///
  /// アプリ起動時と、予定の登録・修正・削除・完了チェックのたびに呼ぶ。
  /// 予約済みをすべて取り消してから入れ直すため、何度呼んでも二重にならない。
  Future<void> rescheduleAll({DateTime? now}) async {
    await initialize();

    final current = now ?? DateTime.now();
    final settings = await _settings.load();
    final horizon = current.add(
      const Duration(days: AppConfig.notificationScheduleHorizonDays + 1),
    );
    final counts = await _schedules.countsForRange(current, horizon);

    final planned = planNotifications(
      now: current,
      countsByDate: counts,
      morningNotifyTime: settings.morningNotifyTime,
      nightNotifyTime: settings.nightNotifyTime,
    );

    await _plugin.cancelAll();
    for (final notification in planned) {
      await _schedule(notification);
    }
  }

  Future<void> _schedule(PlannedNotification notification) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: tz.TZDateTime.from(notification.scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      ),
      // 省電力状態でも可能な限り時刻どおりに届ける。
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: notification.payload,
    );
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }
}
