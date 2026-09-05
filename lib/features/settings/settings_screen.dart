import 'package:app_settings/app_settings.dart' as os_settings;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/clock_time.dart';
import '../../core/theme.dart';
import '../../core/widgets/clock_time_picker.dart';
import '../../data/settings_repository.dart';
import '../../providers.dart';

/// S-08 設定画面。（要件定義書 4.8）
///
/// - 前日夜・当日朝の通知時刻の変更
/// - 起床・就寝のおおよその時刻の変更
/// - 各種利用許可の状態確認
///
/// ▶ 起床・就寝を変えたときの挙動（要ご確認）
/// 起床・就寝の時刻を変えると、通知時刻も30分前に合わせて変わる。
/// 変更が同じ画面上ですぐ見えるため予測しやすく、追随させない場合に
/// 「いつもの時刻を変えたのに通知が変わらない」という食い違いも起きない。
/// 通知時刻だけを個別に決めたい場合は、そのあとで通知時刻を直接変更できる。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _notificationsEnabled;
  bool? _speechAvailable;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifications =
        await ref.read(notificationServiceProvider).areNotificationsEnabled();
    final speech = await ref.read(speechServiceProvider).initialize();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notifications;
      _speechAvailable = speech;
    });
  }

  Future<ClockTime?> _pickTime(ClockTime current) =>
      showClockTimePicker(context: context, initial: current);

  Future<void> _changeNotifyTime(
    AppSettings settings, {
    required bool isNight,
  }) async {
    final picked = await _pickTime(
      isNight ? settings.nightNotifyTime : settings.morningNotifyTime,
    );
    if (picked == null) return;

    await ref.read(settingsProvider.notifier).save(
          settings.copyWith(
            nightNotifyTime: isNight ? picked : null,
            morningNotifyTime: isNight ? null : picked,
            notifyTimeConfirmed: true,
          ),
        );
  }

  /// 起床・就寝の変更。通知時刻も30分前に合わせて更新する。（要件定義書 6.2）
  Future<void> _changeSleepSchedule(
    AppSettings settings, {
    required bool isSleep,
  }) async {
    final picked =
        await _pickTime(isSleep ? settings.sleepTime : settings.wakeTime);
    if (picked == null) return;

    await ref.read(settingsProvider.notifier).saveSleepSchedule(
          sleepTime: isSleep ? picked : settings.sleepTime,
          wakeTime: isSleep ? settings.wakeTime : picked,
        );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (settings) => ListView(
            padding: const EdgeInsets.all(AppTheme.gutter),
            children: [
              // ---- お知らせの時刻 ----
              const _SectionTitle(AppStrings.settingsNotifySection),
              _SettingRow(
                label: AppStrings.notifySetupNightLabel,
                value: settings.nightNotifyTime.toString(),
                onTap: () => _changeNotifyTime(settings, isNight: true),
              ),
              _SettingRow(
                label: AppStrings.notifySetupMorningLabel,
                value: settings.morningNotifyTime.toString(),
                onTap: () => _changeNotifyTime(settings, isNight: false),
              ),

              // ---- いつもの時刻 ----
              const SizedBox(height: 24),
              const _SectionTitle(AppStrings.settingsSleepSection),
              _SettingRow(
                label: AppStrings.settingsSleepLabel,
                value: settings.sleepTime.toString(),
                onTap: () => _changeSleepSchedule(settings, isSleep: true),
              ),
              _SettingRow(
                label: AppStrings.settingsWakeLabel,
                value: settings.wakeTime.toString(),
                onTap: () => _changeSleepSchedule(settings, isSleep: false),
              ),
              const SizedBox(height: 8),
              _Note(AppStrings.settingsSleepNote),

              // ---- 利用の許可 ----
              const SizedBox(height: 24),
              const _SectionTitle(AppStrings.settingsPermissionSection),
              _PermissionRow(
                label: AppStrings.settingsPermissionSpeech,
                granted: _speechAvailable,
              ),
              _PermissionRow(
                label: AppStrings.settingsPermissionNotification,
                granted: _notificationsEnabled,
              ),
              const SizedBox(height: 8),
              _Note(AppStrings.settingsPermissionNote),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                // 許可の変更は OS 側でしか行えないため、端末の設定へ案内する。
                onPressed: () => os_settings.AppSettings.openAppSettings(),
                icon: const Icon(Icons.open_in_new),
                label: const Text(AppStrings.settingsOpenOsSettings),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

/// タップして値を変える行。
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppTheme.minTapSize),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 許可の状態表示。（要件定義書 4.8）
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});

  final String label;

  /// null は確認中。
  final bool? granted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String status;
    final Color color;
    if (granted == null) {
      status = '';
      color = theme.colorScheme.onSurfaceVariant;
    } else if (granted!) {
      status = AppStrings.settingsPermissionGranted;
      color = theme.colorScheme.onSurfaceVariant;
    } else {
      status = AppStrings.settingsPermissionDenied;
      color = theme.colorScheme.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              Text(
                status,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
