import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/app_strings.dart';
import '../../core/date_key.dart';
import '../../core/date_label.dart';
import '../../core/theme.dart';
import '../../core/widgets/clock_time_picker.dart';
import '../../domain/parser/parsed_schedule.dart';
import '../../providers.dart';
import '../card/card_screen.dart';
import '../notify_setup/notify_time_screen.dart';

/// S-03 登録確認画面。
///
/// 聞き取った内容を、日付・予定名に分解して表示する。
/// 複数の予定をまとめて発話した場合は複数行に分けて表示する。（要件定義書 4.3）
///
/// ■ この画面を必ず挟む理由
/// 音声認識は100%正確ではない。登録前に内容を確認・修正できる画面を挟むことで、
/// 認識精度の限界が体験を損なわないようにする。（要件定義書 4.3）
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.items});

  final List<ParsedSchedule> items;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  late List<_DraftSchedule> _drafts;

  /// 修正モード。既定は確認のみの表示にして情報量を抑える。
  bool _editing = false;

  bool _saving = false;

  /// 日付ごとの「あと何件登録できるか」。（要件定義書 2.2）
  Map<DateTime, int> _remaining = const {};
  bool _capacityLoaded = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.items.map(_DraftSchedule.fromParsed).toList();

    // 日付が聞き取れなかった行がある場合は、最初から修正モードで開く。
    // 「聞き取れませんでした」で終わらせず、手直しできる状態にする。（要件定義書 4.9）
    _editing = _drafts.any((draft) => draft.date == null);

    _refreshCapacity();
  }

  /// 対象日の残り登録可能件数を読み直す。日付を変更するたびに呼ぶ。
  Future<void> _refreshCapacity() async {
    final dates = _drafts
        .map((draft) => draft.date)
        .whereType<DateTime>()
        .toList(growable: false);

    final remaining = dates.isEmpty
        ? <DateTime, int>{}
        : await ref
            .read(scheduleRepositoryProvider)
            .remainingCapacityForDates(dates);

    if (!mounted) return;
    setState(() {
      _remaining = remaining;
      _capacityLoaded = true;
    });
  }

  /// 同じ日に何件追加しようとしているか。
  Map<DateTime, int> get _requestedPerDate {
    final counts = <DateTime, int>{};
    for (final draft in _drafts) {
      final date = draft.date;
      if (date == null) continue;
      counts[dateOnly(date)] = (counts[dateOnly(date)] ?? 0) + 1;
    }
    return counts;
  }

  /// 日付ごとにまとめた登録候補。
  ///
  /// 画面イメージでは、話しかけた内容がそのまま「安心カード」として
  /// 1枚に組み上がる。ただし複数の日にまたがる発話（「明日…」「21日に…」）は
  /// 実際には別の日の予定になるため、日付ごとにカードを分けて見せる。
  /// 日付を聞き取れなかった分は最後にまとめる。
  List<({DateTime? date, List<_DraftSchedule> drafts})> get _groups {
    final byDate = <DateTime, List<_DraftSchedule>>{};
    final undated = <_DraftSchedule>[];

    for (final draft in _drafts) {
      final date = draft.date;
      if (date == null) {
        undated.add(draft);
      } else {
        byDate.putIfAbsent(dateOnly(date), () => []).add(draft);
      }
    }

    final dates = byDate.keys.toList()..sort();
    return [
      for (final date in dates) (date: date, drafts: byDate[date]!),
      if (undated.isNotEmpty) (date: null, drafts: undated),
    ];
  }

  /// この画面の内容を登録したあと、その日にあと何件入れられるか。
  ///
  /// 表示しているのはこれから登録される分なので、既存の空きからその件数を
  /// 差し引いた「登録後」の残りを見せる。差し引かないと、登録前と登録後で
  /// 数が食い違って見える。（お客様ご指摘）
  /// null は未取得または日付未確定。
  int? _remainingAfterRegister(DateTime date) {
    final key = dateOnly(date);
    final current = _remaining[key];
    if (current == null) return null;
    final requested = _requestedPerDate[key] ?? 0;
    final after = current - requested;
    return after < 0 ? 0 : after;
  }

  /// 上限を超えてしまう日。1件も入らない日と、入りきらない日の両方を含む。
  List<DateTime> get _overCapacityDates {
    final over = <DateTime>[];
    _requestedPerDate.forEach((date, requested) {
      final remaining = _remaining[date];
      if (remaining != null && requested > remaining) over.add(date);
    });
    return over..sort();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  bool get _canRegister => _capacityLoaded && _validationMessage == null;

  /// 登録できない理由。登録できるなら null。
  String? get _validationMessage {
    if (_drafts.isEmpty) return null;

    if (_drafts.any((draft) => draft.date == null)) {
      return AppStrings.confirmDateMissing;
    }
    if (_drafts.any((draft) => draft.title.trim().isEmpty)) {
      return AppStrings.confirmTitleMissing;
    }

    // 1日あたりの上限。（要件定義書 2.2）
    // 「登録できません」で終わらせず、上限の理由と、別日なら登録できることを伝える。
    final over = _overCapacityDates;
    if (over.isNotEmpty) {
      return AppStrings.fill(AppStrings.confirmLimitReached, {
        'date': dateLabel(over.first),
        'max': '${AppConfig.maxSchedulesPerDay}',
      });
    }

    return null;
  }

  Future<void> _register() async {
    if (!_canRegister || _saving) return;
    setState(() => _saving = true);

    // 上限は登録直前にも確かめる。表示してから押されるまでの間に
    // 別経路で予定が増えている可能性があるため。（要件定義書 2.2）
    await _refreshCapacity();
    if (!mounted) return;
    if (_overCapacityDates.isNotEmpty) {
      setState(() => _saving = false);
      return;
    }

    final repository = ref.read(scheduleRepositoryProvider);
    for (final draft in _drafts) {
      await repository.insert(
        title: draft.title.trim(),
        baseDate: draft.date!,
        time: draft.time,
        repeat: draft.repeat,
        weekday: draft.weekday,
      );
    }

    // 予定が変わったので通知の予約を作り直す。件数を含む文面は
    // 予約時点で固定されるため、登録のたびに必要になる。
    await ref.read(notificationServiceProvider).rescheduleAll();
    await ref.read(cardsProvider.notifier).reload();

    // 初回の登録に限り、通知時刻の確認（S-04）を挟む。
    // 一度設定した時刻は以降の登録にも引き継がれ、毎回設定する必要はない。
    // （要件定義書 4.4）
    final settings = await ref.read(settingsProvider.future);
    if (!mounted) return;
    if (!settings.notifyTimeConfirmed) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const NotifyTimeScreen()),
      );
      if (!mounted) return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => CardScreen(initialDate: _drafts.first.date),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // 画面イメージでは S-02 と同じ見出しを掲げ、同じ流れの続きであることを示す。
      appBar: AppBar(title: const Text(AppStrings.registerScreenTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppTheme.gutter),
                itemCount: _groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  return _DraftCard(
                    date: group.date,
                    drafts: group.drafts,
                    editing: _editing,
                    remaining: group.date == null
                        ? null
                        : _remainingAfterRegister(group.date!),
                    blocked: group.date != null &&
                        _overCapacityDates.contains(group.date),
                    onChanged: () => setState(() {}),
                    // 日付が変わると対象日の空き状況も変わるため読み直す。
                    onDateChanged: () {
                      setState(() {});
                      _refreshCapacity();
                    },
                  );
                },
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
                  if (_validationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _validationMessage!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: _canRegister && !_saving ? _register : null,
                    child: const Text(AppStrings.confirmRegister),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _editing
                        ? null
                        : () => setState(() => _editing = true),
                    child: const Text(AppStrings.confirmEdit),
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

/// 登録前の1件分。画面上で編集される中間状態。
class _DraftSchedule {
  _DraftSchedule({
    required this.titleController,
    required this.date,
    required this.time,
    required this.repeat,
    required this.weekday,
  });

  factory _DraftSchedule.fromParsed(ParsedSchedule parsed) {
    return _DraftSchedule(
      titleController: TextEditingController(text: parsed.title),
      date: parsed.date,
      time: parsed.time,
      repeat: parsed.repeat,
      weekday: parsed.weekday,
    );
  }

  final TextEditingController titleController;
  DateTime? date;
  ClockTime? time;
  RepeatType repeat;
  int? weekday;

  String get title => titleController.text;

  void dispose() => titleController.dispose();
}

/// 同じ日に登録される予定を1枚のカードにまとめて見せる。
///
/// 画面イメージの登録確認画面は「話しかけた内容で『今日の安心カード』が
/// 作成される」という見せ方をしている。登録後に現れるカードと同じ形で
/// 確認できるようにすることで、何が起きるのかが一目で分かる。
class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.date,
    required this.drafts,
    required this.editing,
    required this.remaining,
    required this.blocked,
    required this.onChanged,
    required this.onDateChanged,
  });

  /// このカードの日付。null は日付を聞き取れなかった分。
  final DateTime? date;

  final List<_DraftSchedule> drafts;
  final bool editing;

  /// 登録後にこの日へあと何件入れられるか。null は未取得または日付未確定。
  final int? remaining;

  /// 上限を超えるため、この日には登録できない状態か。
  /// 登録した結果ちょうど上限に達する場合（残り0件）と区別する。
  final bool blocked;

  final VoidCallback onChanged;
  final VoidCallback onDateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カードの名前と日付。登録後に現れるカードと同じ並びにする。
            Text(
              date == null
                  ? AppStrings.confirmDateMissing
                  : cardName(
                      dateOnly(date!).difference(dateOnly(DateTime.now())).inDays,
                      date!,
                    ),
              // 登録後のカードと同じブランドカラーで揃える。
              // 日付が聞き取れていない場合だけ、直すべき箇所として赤で示す。
              style: theme.textTheme.titleLarge?.copyWith(
                color: date == null
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            if (date != null) ...[
              const SizedBox(height: 4),
              Text(
                fullDateLabel(date!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final draft in drafts)
              _DraftRow(
                draft: draft,
                editing: editing,
                onChanged: onChanged,
                onDateChanged: onDateChanged,
              ),
            // その日の空き状況。上限に達していることが登録前に分かるようにする。
            // （要件定義書 2.2）
            if (remaining != null) ...[
              const SizedBox(height: 12),
              Text(
                remaining! <= 0
                    ? AppStrings.confirmLimitBadge
                    : AppStrings.withCount(
                        AppStrings.confirmRemaining,
                        remaining!,
                      ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: blocked
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// カード内の予定1件分。
class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.editing,
    required this.onChanged,
    required this.onDateChanged,
  });

  final _DraftSchedule draft;
  final bool editing;
  final VoidCallback onChanged;
  final VoidCallback onDateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (editing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: draft.titleController,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: AppStrings.editNameLabel,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DateChip(
                  draft: draft,
                  editing: editing,
                  onChanged: onDateChanged,
                ),
                _TimeChip(draft: draft, editing: editing, onChanged: onChanged),
                if (draft.repeat != RepeatType.none)
                  Chip(label: Text(_repeatLabel(draft))),
              ],
            ),
          ],
        ),
      );
    }

    // 確認モードは、登録後のカードと同じ「チェックボックス＋予定名」の並び。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppTheme.listRowMinHeight,
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_box_outline_blank,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(draft.title, style: theme.textTheme.bodyLarge),
                  if (draft.time != null || draft.repeat != RepeatType.none)
                    Text(
                      [
                        if (draft.time != null) draft.time.toString(),
                        if (draft.repeat != RepeatType.none)
                          _repeatLabel(draft),
                      ].join('  '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _repeatLabel(_DraftSchedule draft) {
    switch (draft.repeat) {
      case RepeatType.none:
        return AppStrings.editRepeatNone;
      case RepeatType.daily:
        return AppStrings.confirmRepeatDaily;
      case RepeatType.weekly:
        final weekday = draft.weekday;
        if (weekday == null) return AppStrings.confirmRepeatWeeklyPrefix;
        const names = ['月', '火', '水', '木', '金', '土', '日'];
        return '${AppStrings.confirmRepeatWeeklyPrefix}${names[weekday - 1]}曜';
    }
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.draft,
    required this.editing,
    required this.onChanged,
  });

  final _DraftSchedule draft;
  final bool editing;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: draft.date ?? dateOnly(now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (selected == null) return;
    draft.date = dateOnly(selected);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final missing = draft.date == null;

    return ActionChip(
      avatar: const Icon(Icons.event_outlined, size: 20),
      label: Text(
        missing ? AppStrings.confirmDateMissing : dateLabel(draft.date!),
      ),
      backgroundColor:
          missing ? Theme.of(context).colorScheme.errorContainer : null,
      onPressed: editing || missing ? () => _pick(context) : null,
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.draft,
    required this.editing,
    required this.onChanged,
  });

  final _DraftSchedule draft;
  final bool editing;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context) async {
    final current = draft.time;
    final selected = await showClockTimePicker(
      context: context,
      initial: current ?? const ClockTime(9, 0),
    );
    if (selected == null) return;
    draft.time = selected;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final time = draft.time;

    return ActionChip(
      avatar: const Icon(Icons.schedule_outlined, size: 20),
      label: Text(time == null ? AppStrings.confirmAllDay : time.toString()),
      onPressed: editing ? () => _pick(context) : null,
    );
  }
}
