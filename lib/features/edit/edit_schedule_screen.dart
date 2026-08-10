import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/app_strings.dart';
import '../../core/clock_time.dart';
import '../../core/date_key.dart';
import '../../core/date_label.dart';
import '../../core/theme.dart';
import '../../data/models/schedule.dart';
import '../../domain/parser/schedule_parser.dart';
import '../../providers.dart';

/// S-07 修正画面。
///
/// 登録済みの予定について、予定名・日付・時刻・繰り返し設定を編集し、
/// 削除もできる。音声での言い直しにも対応する。（要件定義書 4.7）
///
/// ▶ この画面は必須機能
/// 画面イメージでは「修正する」ボタンの先が未定だったが、音声認識は必ず
/// 誤りを含むため、修正フローはオプションではなく必須と位置づけている。
///
/// ▶ 繰り返し予定の変更範囲
/// [AppConfig.repeatEditScope] に従い、今後すべての回へ適用する。
/// 「この日だけ」の選択肢は、対象利用者にとって判断の負荷になるため出さない。
class EditScheduleScreen extends ConsumerStatefulWidget {
  const EditScheduleScreen({super.key, required this.schedule});

  final Schedule schedule;

  @override
  ConsumerState<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends ConsumerState<EditScheduleScreen> {
  late final TextEditingController _titleController;
  late DateTime _date;
  late ClockTime? _time;
  late RepeatType _repeat;
  late int? _weekday;

  bool _saving = false;
  bool _listening = false;
  String _recognized = '';

  /// 上限などで保存できなかった理由。
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _titleController = TextEditingController(text: schedule.title);
    _date = schedule.baseDate;
    _time = schedule.time;
    _repeat = schedule.repeat;
    _weekday = schedule.weekday;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSave => _titleController.text.trim().isNotEmpty && !_saving;

  // ---------------------------------------------------------------------------
  // 音声での言い直し（要件定義書 4.7）
  // ---------------------------------------------------------------------------

  Future<void> _startReRecord() async {
    final speech = ref.read(speechServiceProvider);
    if (!speech.isAvailable) {
      final available = await speech.initialize();
      if (!available) return;
    }
    if (!mounted) return;

    setState(() {
      _listening = true;
      _recognized = '';
    });

    await speech.startListening(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _recognized = result.text);
        if (result.isFinal) _applyReRecord();
      },
    );
  }

  Future<void> _stopReRecord() async {
    await ref.read(speechServiceProvider).stopListening();
    if (!mounted) return;
    _applyReRecord();
  }

  /// 聞き取った内容で各項目を差し替える。
  ///
  /// 解析できた項目だけを上書きし、聞き取れなかった項目は元の値を残す。
  /// 言い直しで情報が減ってしまうのを避けるため。
  void _applyReRecord() {
    if (!_listening) return;
    setState(() => _listening = false);

    final text = _recognized.trim();
    if (text.isEmpty) return;

    final parsed = ScheduleParser().parse(text);
    if (parsed.isEmpty) return;
    final first = parsed.first;

    setState(() {
      if (first.title.isNotEmpty) _titleController.text = first.title;
      if (first.date != null) _date = first.date!;
      if (first.time != null) _time = first.time;
      if (first.repeat != RepeatType.none) {
        _repeat = first.repeat;
        _weekday = first.weekday;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 保存・削除
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    // 別の日へ移すときは、移動先の空きを確かめる。（要件定義書 2.2）
    // 同じ日のままなら件数は変わらないため判定不要。
    if (!isSameDate(_date, widget.schedule.baseDate)) {
      final remaining =
          await ref.read(scheduleRepositoryProvider).remainingCapacityOn(_date);
      if (!mounted) return;
      if (remaining <= 0) {
        setState(() {
          _saving = false;
          _errorMessage = AppStrings.fill(AppStrings.confirmLimitReached, {
            'date': dateLabel(_date),
            'max': '${AppConfig.maxSchedulesPerDay}',
          });
        });
        return;
      }
    }

    final updated = widget.schedule.copyWith(
      title: _titleController.text.trim(),
      baseDate: _date,
      time: _time,
      clearTime: _time == null,
      repeat: _repeat,
      weekday: _repeat == RepeatType.weekly ? _weekday : null,
    );

    await ref.read(scheduleRepositoryProvider).update(updated);
    await _refreshAndClose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.editDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.editDeleteConfirmNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.editDeleteConfirmYes),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);

    await ref.read(scheduleRepositoryProvider).delete(widget.schedule.id);
    await _refreshAndClose();
  }

  /// 予定が変わったので、通知の予約とカードを作り直してから閉じる。
  Future<void> _refreshAndClose() async {
    await ref.read(notificationServiceProvider).rescheduleAll();
    await ref.read(cardsProvider.notifier).reload();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------------------
  // 入力
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (selected == null) return;
    setState(() => _date = dateOnly(selected));
  }

  Future<void> _pickTime() async {
    final current = _time;
    final selected = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (selected == null) return;
    setState(() => _time = ClockTime(selected.hour, selected.minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.gutter),
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: AppStrings.editNameLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FieldRow(
                    label: AppStrings.editDateLabel,
                    value: dateLabel(_date),
                    icon: Icons.event_outlined,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 8),
                  _FieldRow(
                    label: AppStrings.editTimeLabel,
                    value: _time?.toString() ?? AppStrings.confirmAllDay,
                    icon: Icons.schedule_outlined,
                    onTap: _pickTime,
                    onClear: _time == null
                        ? null
                        : () => setState(() => _time = null),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.editRepeatLabel,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _RepeatSelector(
                    repeat: _repeat,
                    weekday: _weekday,
                    date: _date,
                    onChanged: (repeat, weekday) => setState(() {
                      _repeat = repeat;
                      _weekday = weekday;
                    }),
                  ),
                  if (_repeat != RepeatType.none) ...[
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.editRepeatScopeNote,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _ReRecordSection(
                    listening: _listening,
                    recognized: _recognized,
                    onStart: _startReRecord,
                    onStop: _stopReRecord,
                  ),
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
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text(AppStrings.editSave),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text(AppStrings.editDelete),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日付・時刻など、タップして選ぶ項目の行。
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTheme.minTapSize),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: theme.textTheme.bodyLarge),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                    tooltip: AppStrings.editClearTime,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 繰り返しの選択。なし／毎日／毎週◯曜の3択に絞る。
class _RepeatSelector extends StatelessWidget {
  const _RepeatSelector({
    required this.repeat,
    required this.weekday,
    required this.date,
    required this.onChanged,
  });

  final RepeatType repeat;
  final int? weekday;
  final DateTime date;
  final void Function(RepeatType repeat, int? weekday) onChanged;

  @override
  Widget build(BuildContext context) {
    // 毎週を選んだときの曜日は、基準日の曜日をそのまま使う。
    // 曜日を別に選ばせると設定項目が増えるため、日付に従わせる。
    final weeklyWeekday = weekday ?? date.weekday;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text(AppStrings.editRepeatNone),
          selected: repeat == RepeatType.none,
          onSelected: (_) => onChanged(RepeatType.none, null),
        ),
        ChoiceChip(
          label: const Text(AppStrings.editRepeatDaily),
          selected: repeat == RepeatType.daily,
          onSelected: (_) => onChanged(RepeatType.daily, null),
        ),
        ChoiceChip(
          label: Text(
            '${AppStrings.editRepeatWeekly}${weekdayLabel(date)}曜',
          ),
          selected: repeat == RepeatType.weekly,
          onSelected: (_) => onChanged(RepeatType.weekly, weeklyWeekday),
        ),
      ],
    );
  }
}

/// 音声での言い直し。（要件定義書 4.7）
class _ReRecordSection extends StatelessWidget {
  const _ReRecordSection({
    required this.listening,
    required this.recognized,
    required this.onStart,
    required this.onStop,
  });

  final bool listening;
  final String recognized;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!listening) {
      return OutlinedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.mic_none_outlined),
        label: const Text(AppStrings.editReRecord),
      );
    }

    return Column(
      children: [
        Text(AppStrings.editListening, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          recognized,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onStop,
          child: const Text(AppStrings.inputStop),
        ),
      ],
    );
  }
}
