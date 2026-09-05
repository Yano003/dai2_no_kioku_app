import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/clock_time.dart';
import '../../core/theme.dart';
import '../../core/widgets/clock_time_picker.dart';
import '../../data/settings_repository.dart';
import '../../providers.dart';

/// S-04 通知時刻設定画面。
///
/// 前日夜・当日朝の2つの通知時刻を設定する。（要件定義書 4.4）
///
/// 初期値は初回設定（S-01）で伺った起床・就寝の時刻から30分前を逆算して
/// 提案する。（要件定義書 6.2）
///
/// この画面は次の2か所から開かれる。
/// 1. 初回の登録直後（S-03 →ここ→ S-05）。2回目以降は挟まない
/// 2. 設定画面（S-08）からの変更
class NotifyTimeScreen extends ConsumerStatefulWidget {
  const NotifyTimeScreen({super.key});

  @override
  ConsumerState<NotifyTimeScreen> createState() => _NotifyTimeScreenState();
}

class _NotifyTimeScreenState extends ConsumerState<NotifyTimeScreen> {
  ClockTime? _nightTime;
  ClockTime? _morningTime;
  bool _saving = false;
  bool? _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final enabled =
        await ref.read(notificationServiceProvider).areNotificationsEnabled();
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  /// 設定の読み込みが終わった時点で、編集用の値を一度だけ初期化する。
  void _seedFrom(AppSettings settings) {
    _nightTime ??= settings.nightNotifyTime;
    _morningTime ??= settings.morningNotifyTime;
  }

  Future<void> _pick({required bool isNight}) async {
    final current = isNight ? _nightTime! : _morningTime!;
    final selected = await showClockTimePicker(
      context: context,
      initial: current,
    );
    if (selected == null) return;
    setState(() {
      if (isNight) {
        _nightTime = selected;
      } else {
        _morningTime = selected;
      }
    });
  }

  Future<void> _save(AppSettings settings) async {
    if (_saving) return;
    setState(() => _saving = true);

    // 保存すると通知の予約もまとめて作り直される。
    await ref.read(settingsProvider.notifier).save(
          settings.copyWith(
            nightNotifyTime: _nightTime,
            morningNotifyTime: _morningTime,
            // 以降の登録ではこの画面を挟まない。（要件定義書 4.4）
            notifyTimeConfirmed: true,
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notifySetupTitle)),
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (settings) {
            _seedFrom(settings);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.gutter),
                    children: [
                      Text(
                        AppStrings.notifySetupDescription,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      _TimeRow(
                        label: AppStrings.notifySetupNightLabel,
                        hint: AppStrings.notifySetupNightHint,
                        time: _nightTime!,
                        onTap: () => _pick(isNight: true),
                      ),
                      const SizedBox(height: 12),
                      _TimeRow(
                        label: AppStrings.notifySetupMorningLabel,
                        hint: AppStrings.notifySetupMorningHint,
                        time: _morningTime!,
                        onTap: () => _pick(isNight: false),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppStrings.notifySetupNote,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_notificationsEnabled == false) ...[
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.notifySetupPermissionDenied,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    0,
                    AppTheme.gutter,
                    16,
                  ),
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(settings),
                    child: const Text(AppStrings.notifySetupSave),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 通知時刻1つ分の行。行全体をタップ領域にする。
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.hint,
    required this.time,
    required this.onTap,
  });

  final String label;
  final String hint;
  final ClockTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTheme.minTapSize),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  time.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
