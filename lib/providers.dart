import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/clock_time.dart';
import 'core/date_key.dart';
import 'data/models/schedule.dart';
import 'data/schedule_repository.dart';
import 'data/settings_repository.dart';
import 'domain/card/day_card.dart';
import 'services/notification_service.dart';
import 'services/speech_service.dart';

// -----------------------------------------------------------------------------
// リポジトリ・サービス
// -----------------------------------------------------------------------------

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(
    scheduleRepository: ref.watch(scheduleRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  ),
);

final speechServiceProvider = Provider<SpeechService>(
  (ref) => SpeechService(),
);

// -----------------------------------------------------------------------------
// 設定
// -----------------------------------------------------------------------------

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() =>
      ref.read(settingsRepositoryProvider).load();

  /// 設定を保存し、通知を予約し直す。
  ///
  /// 通知時刻が変わると予約済みの通知はすべて作り直す必要がある。
  Future<void> save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
    // カードは settingsProvider を watch しているため、state の更新で
    // 自動的に作り直される。ここでの明示的な invalidate は不要。
    await ref.read(notificationServiceProvider).rescheduleAll();
  }

  /// 起床・就寝時刻から通知時刻を逆算して設定する。（要件定義書 6.2）
  ///
  /// S-08 設定画面からの変更でも使う。
  Future<void> saveSleepSchedule({
    required ClockTime wakeTime,
    required ClockTime sleepTime,
  }) async {
    final current = state.value ?? AppSettings.defaults;
    await save(
      current.copyWith(
        wakeTime: wakeTime,
        sleepTime: sleepTime,
        morningNotifyTime: AppSettings.morningNotifyFor(wakeTime),
        nightNotifyTime: AppSettings.nightNotifyFor(sleepTime),
      ),
    );
  }

  /// 初回起動案内（S-01）の完了。
  ///
  /// 伺った起床・就寝時刻から通知時刻を逆算し、案内の完了フラグと合わせて
  /// 一度だけ保存する。保存を分けると通知の予約が二重に走るため、まとめる。
  ///
  /// [termsAgreedAt] は案内の1画面目（同意画面）で「同意してはじめる」を
  /// 押した時刻。利用規約 第1条の同意記録として保存する。
  Future<void> completeOnboarding({
    required ClockTime wakeTime,
    required ClockTime sleepTime,
    required DateTime termsAgreedAt,
  }) async {
    final current = state.value ?? AppSettings.defaults;
    await save(
      current.copyWith(
        wakeTime: wakeTime,
        sleepTime: sleepTime,
        morningNotifyTime: AppSettings.morningNotifyFor(wakeTime),
        nightNotifyTime: AppSettings.nightNotifyFor(sleepTime),
        onboardingCompleted: true,
        termsAgreedAt: termsAgreedAt,
      ),
    );
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// -----------------------------------------------------------------------------
// カード
// -----------------------------------------------------------------------------

/// 読み込み済みのカードの範囲。
///
/// 端末内のデータ量は小さいため、表示中の日付の前後をまとめて読み込む。
/// 範囲外へスクロールされたら [CardsNotifier.ensureRange] で広げる。
class CardWindow {
  const CardWindow({
    required this.from,
    required this.to,
    required this.cards,
  });

  final DateTime from;
  final DateTime to;
  final Map<DateTime, DayCard> cards;

  DayCard? cardFor(DateTime date) => cards[dateOnly(date)];

  bool contains(DateTime date) {
    final target = dateOnly(date);
    return !target.isBefore(from) && !target.isAfter(to);
  }
}

class CardsNotifier extends AsyncNotifier<CardWindow> {
  /// 初回に読み込む前後の日数。
  static const _initialSpanDays = 45;

  /// 範囲を広げるときの追加日数。
  static const _extendSpanDays = 60;

  late DateTime _from;
  late DateTime _to;

  @override
  Future<CardWindow> build() async {
    // 通知時刻が変わるとカードの表示パターンの境界も変わるため、
    // 設定を監視して作り直す。watch は build の中でしか呼べない。
    ref.watch(settingsProvider);

    final today = dateOnly(DateTime.now());
    _from = today.subtract(const Duration(days: _initialSpanDays));
    _to = today.add(const Duration(days: _initialSpanDays));
    return _load();
  }

  Future<CardWindow> _load() async {
    final repository = ref.read(scheduleRepositoryProvider);
    // _load は利用者の操作からも呼ばれる。build の外なので read を使う。
    final settings = await ref.read(settingsProvider.future);

    final entries = await repository.entriesForRange(_from, _to);
    final acknowledged = await repository.acknowledgedDates(_from, _to);
    final now = DateTime.now();

    final cards = <DateTime, DayCard>{};
    entries.forEach((date, list) {
      cards[date] = buildDayCard(
        date: date,
        entries: list,
        now: now,
        morningNotifyTime: settings.morningNotifyTime,
        nightNotifyTime: settings.nightNotifyTime,
        acknowledged: acknowledged.contains(date),
      );
    });

    return CardWindow(from: _from, to: _to, cards: cards);
  }

  Future<void> _refresh() async {
    state = AsyncData(await _load());
  }

  /// 指定日が読み込み済みの範囲に入るよう、必要なら範囲を広げる。
  Future<void> ensureRange(DateTime date) async {
    final target = dateOnly(date);
    if (!target.isBefore(_from) && !target.isAfter(_to)) return;

    if (target.isBefore(_from)) {
      _from = target.subtract(const Duration(days: _extendSpanDays));
    } else {
      _to = target.add(const Duration(days: _extendSpanDays));
    }
    await _refresh();
  }

  /// 完了チェックを切り替える。（要件定義書 4.5）
  ///
  /// 繰り返し予定でも、チェックは日付ごとに独立して保存される。
  Future<void> toggleCompleted(ScheduleEntry entry) async {
    await ref.read(scheduleRepositoryProvider).setCompleted(
          scheduleId: entry.schedule.id,
          date: entry.date,
          completed: !entry.isCompleted,
        );
    await _refresh();
  }

  /// 「確認しました」を記録する。（確認事項 No.4）
  Future<void> acknowledge(DateTime date) async {
    await ref.read(scheduleRepositoryProvider).acknowledgeCard(date);
    await _refresh();
  }

  /// 予定を登録したあとなど、外部の変更を反映する。
  Future<void> reload() => _refresh();
}

final cardsProvider =
    AsyncNotifierProvider<CardsNotifier, CardWindow>(CardsNotifier.new);
