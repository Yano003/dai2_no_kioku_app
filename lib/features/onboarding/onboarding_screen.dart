import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/app_strings.dart';
import '../../core/clock_time.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../input/input_screen.dart';

/// S-01 初回起動案内。
///
/// 初回起動時のみ表示し、利用許可を1つずつ順に取得する。（要件定義書 4.1）
/// あわせて、通知時刻の逆算に使う起床・就寝のおおよその時刻を伺う。
/// （要件定義書 6.2。画面一覧には無いが、6.2 の実装に必須のため本画面に含める）
///
/// ▶ 設計上の注意：初回起動が最大の離脱点
/// デジタル操作に不慣れな利用者にとって、起動直後に許可ダイアログが連続する
/// 場面が最も脱落しやすい。1画面につき1つのことだけを伝え、専門用語を使わず、
/// どの段階でも「あとで」で先へ進めるようにしている。
///
/// ▶ 許可の段階について（要件定義書 4.1 との差異・要ご確認）
/// 要件定義書では「マイク・音声認識・通知」を1つずつ3段階で取得するとあるが、
/// マイクと音声認識の許可は OS 側が1回の呼び出しでまとめて要求する仕様のため、
/// 技術的に分割できない（iOS は2つのダイアログが連続して出る／Android は
/// マイクのみ）。そこで「声を使うこと」と「お知らせ」の2段階にしている。
/// ダイアログを分割できない以上、段階を増やすと説明だけの画面が挟まり、
/// かえって離脱点が増えるため、この形が要件の意図に沿うと判断した。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 5;

  int _step = 0;
  bool _busy = false;

  ClockTime _sleepTime = AppConfig.defaultSleepTime;
  ClockTime _wakeTime = AppConfig.defaultWakeTime;

  void _next() {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  /// 声（マイク・文字起こし）の利用許可を求める。
  ///
  /// 拒否されても先へ進める。文字入力での登録は引き続き使えるため、
  /// ここで足止めしない。（要件定義書 4.1）
  Future<void> _requestSpeech() async {
    setState(() => _busy = true);
    await ref.read(speechServiceProvider).initialize();
    if (!mounted) return;
    setState(() => _busy = false);
    _next();
  }

  /// 通知の利用許可を求める。拒否されてもアプリは動く。
  Future<void> _requestNotification() async {
    setState(() => _busy = true);
    await ref.read(notificationServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() => _busy = false);
    _next();
  }

  Future<void> _pickTime({required bool isSleep}) async {
    final current = isSleep ? _sleepTime : _wakeTime;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (selected == null) return;
    setState(() {
      final picked = ClockTime(selected.hour, selected.minute);
      if (isSleep) {
        _sleepTime = picked;
      } else {
        _wakeTime = picked;
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _busy = true);

    // 起床・就寝から通知時刻を逆算し、案内の完了とあわせて一度で保存する。
    await ref.read(settingsProvider.notifier).completeOnboarding(
          wakeTime: _wakeTime,
          sleepTime: _sleepTime,
        );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const InputScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _StepIndicator(current: _step, total: _stepCount),
              Expanded(child: _buildStep()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepLayout(
          title: AppStrings.onboardingWelcomeTitle,
          body: AppStrings.onboardingWelcomeBody,
          icon: Icons.wb_twilight_outlined,
          primaryLabel: AppStrings.onboardingNext,
          onPrimary: _busy ? null : _next,
        );

      case 1:
        return _StepLayout(
          title: AppStrings.onboardingMicTitle,
          // マイクと文字起こしの両方をここで説明する。OS のダイアログは
          // この直後にまとめて出る。
          body: '${AppStrings.onboardingMicBody}\n'
              '${AppStrings.onboardingSpeechBody}',
          note: AppStrings.onboardingSpeechOptional,
          icon: Icons.mic_none_outlined,
          primaryLabel: AppStrings.onboardingAllow,
          onPrimary: _busy ? null : _requestSpeech,
          secondaryLabel: AppStrings.onboardingSkip,
          onSecondary: _busy ? null : _next,
        );

      case 2:
        return _StepLayout(
          title: AppStrings.onboardingNotificationTitle,
          body: AppStrings.onboardingNotificationBody,
          note: AppStrings.onboardingNotificationOptional,
          icon: Icons.notifications_none_outlined,
          primaryLabel: AppStrings.onboardingAllow,
          onPrimary: _busy ? null : _requestNotification,
          secondaryLabel: AppStrings.onboardingSkip,
          onSecondary: _busy ? null : _next,
        );

      case 3:
        return _StepLayout(
          title: AppStrings.onboardingSleepQuestion,
          body: AppStrings.onboardingSleepBody,
          icon: Icons.bedtime_outlined,
          content: _TimeButton(
            time: _sleepTime,
            onTap: () => _pickTime(isSleep: true),
          ),
          primaryLabel: AppStrings.onboardingNext,
          onPrimary: _busy ? null : _next,
        );

      case 4:
        return _StepLayout(
          title: AppStrings.onboardingWakeQuestion,
          body: AppStrings.onboardingWakeBody,
          note: AppStrings.onboardingLaterNote,
          icon: Icons.wb_sunny_outlined,
          content: _TimeButton(
            time: _wakeTime,
            onTap: () => _pickTime(isSleep: false),
          ),
          primaryLabel: AppStrings.onboardingStart,
          onPrimary: _busy ? null : _finish,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// 何画面中の何画面目かを示す点。残りが見えると心理的な負担が下がる。
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= current ? colors.primary : colors.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// 各ステップの共通レイアウト。1画面につき1つのことだけを伝える。
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.body,
    required this.icon,
    required this.primaryLabel,
    required this.onPrimary,
    this.note,
    this.content,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String? note;
  final IconData icon;

  /// 説明の下に置く追加の要素（時刻を選ぶボタンなど）。
  final Widget? content;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          // 文字サイズを大きくしても収まるようスクロールさせる。
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Icon(icon, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text(body, style: theme.textTheme.bodyLarge),
                if (content != null) ...[
                  const SizedBox(height: 32),
                  content!,
                ],
                if (note != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    note!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
        if (secondaryLabel != null)
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel!))
        else
          const SizedBox(height: AppTheme.minTapSize),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// 起床・就寝時刻を選ぶ大きなボタン。
class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.time, required this.onTap});

  final ClockTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            children: [
              Text(
                time.toString(),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.onboardingTapToChange,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
