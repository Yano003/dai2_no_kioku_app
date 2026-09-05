import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_strings.dart';
import '../../core/date_label.dart';
import '../../core/theme.dart';
import '../../data/models/schedule.dart';
import '../../domain/card/day_card.dart';

/// 安心カード1枚分の表示。（要件定義書 4.5 / S-05）
///
/// 画面イメージのカードは、上から
///   カードの名前 → 日付 → 本文 → 予定一覧 → 全部できたときの一言
///   → 結びの言葉
/// の順に並ぶ。表示パターンごとの出し分けは [DayCard.variant] から決まる。
///
/// 末尾にあった「おやすみなさい」「いってらっしゃい」ボタンは 2026/09/05 に
/// 廃止し、言葉だけを残している。（クライアントご指示）
///
/// 文言はすべて仮であり、[AppStrings] の差し替えで確定する。
class DayCardView extends StatelessWidget {
  const DayCardView({
    super.key,
    required this.card,
    required this.onToggleEntry,
    required this.onEditEntry,
  });

  final DayCard card;
  final void Function(ScheduleEntry entry) onToggleEntry;

  /// 予定の行から S-07 修正画面を開く。（要件定義書 4.7）
  final void Function(ScheduleEntry entry) onEditEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gutter,
          vertical: 24,
        ),
        // 文字サイズを大きくしても内容が切れないよう、カード内はスクロールする。
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // カードの名前。ブランドカラーで置き、このカードが
              // 何のカードかを最初に伝える。（お客様ご指摘）
              Text(
                cardName(card.dayOffset, card.date),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fullDateLabel(card.date),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _Message(card: card),
              const SizedBox(height: 12),
              // 予定がない日は本文の「明日の予定はありません。」だけを出し、
              // 空の一覧や不足を思わせる表示は置かない。（要件定義書 4.9）
              ...card.entries.map(
                (entry) => _EntryRow(
                  entry: entry,
                  enabled: card.isCheckable,
                  onToggle: () => onToggleEntry(entry),
                  onEdit: () => onEditEntry(entry),
                ),
              ),
              _AllDoneMessage(card: card),
              _ClosingLines(card: card),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表示パターンごとの本文。（要件定義書 4.5 の表）
class _Message extends StatelessWidget {
  const _Message({required this.card});

  final DayCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _messageFor(card);
    if (message.isEmpty) return const SizedBox.shrink();

    return Text(message, style: theme.textTheme.bodyLarge);
  }

  static String _messageFor(DayCard card) {
    switch (card.variant) {
      case CardVariant.previousNight:
        return card.isEmpty ? _empty(card) : AppStrings.cardPreviousNight;
      case CardVariant.morning:
        return card.isEmpty
            ? _empty(card)
            : AppStrings.withCount(AppStrings.cardMorning, card.total);
      case CardVariant.daytime:
        // 日中は予定一覧が主役。見出しで急かさない。
        return card.isEmpty ? _empty(card) : '';
      case CardVariant.future:
        return card.isEmpty ? _empty(card) : AppStrings.cardFuture;
      case CardVariant.past:
        return card.isEmpty ? _empty(card) : AppStrings.cardPast;
    }
  }

  /// 予定がない日の本文。「明日の予定はありません。」のように、
  /// どの日のことかを本文だけで分かるようにする。（お客様ご指摘 2026/08/17）
  static String _empty(DayCard card) => AppStrings.fill(
        AppStrings.cardEmpty,
        {'day': cardDayLabel(card.dayOffset, card.date)},
      );
}

/// 予定をすべて完了したときに、一覧の下へ現れる労いの言葉。
/// （お客様ご指摘 2026/08/17）
///
/// 最後の1つにチェックが付いた時点でその場に現れる。専用のカードや画面には
/// せず、いま見ているカードの中で完結させる。
class _AllDoneMessage extends StatelessWidget {
  const _AllDoneMessage({required this.card});

  final DayCard card;

  @override
  Widget build(BuildContext context) {
    // 予定が0件の日を「すべてできました」と祝うのは不自然なため、
    // [DayCard.allCompleted] は1件以上ある日にだけ真になる。
    if (!card.allCompleted) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.cardAllDone, style: style),
          // 2行目はその日のうちだけ。翌日以降は1行だけ残す。
          if (card.dayOffset >= 0)
            Text(AppStrings.cardAllDoneRelax, style: style),
        ],
      ),
    );
  }
}

/// 予定一覧の下に添える結びの言葉。
///
/// 前日夜は「その晩の一言」＋「おやすみなさい」の2行、当日朝は「いい1日を」の
/// 1行。どちらも同じ大きさで並べる。（クライアントご指示 2026/09/05）
///
/// 以前はここに「おやすみなさい」「いってらっしゃい」のボタンを置いていたが、
/// 押しても何も起きないボタンだったため廃止し、言葉だけを残している。
class _ClosingLines extends StatelessWidget {
  const _ClosingLines({required this.card});

  final DayCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = _closingFor(card);
    if (lines.isEmpty) return const SizedBox.shrink();

    final style = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines) Text(line, style: style),
        ],
      ),
    );
  }

  static List<String> _closingFor(DayCard card) {
    switch (card.variant) {
      case CardVariant.previousNight:
        return [
          // 予定がない日に「明日はこれだけ〜」の締めを置かないのは
          // 従来どおり。「おやすみなさい」はどちらの日にも残す。
          if (!card.isEmpty) AppStrings.previousNightClosingFor(card.date),
          AppStrings.cardGoodNight,
        ];
      case CardVariant.morning:
        return const [AppStrings.cardHaveANiceDay];
      case CardVariant.daytime:
      case CardVariant.future:
      case CardVariant.past:
        return const [];
    }
  }
}

/// 予定1件分の行。完了チェック付き。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
  });

  final ScheduleEntry entry;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: enabled ? onToggle : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ConstrainedBox(
          // 行そのものを十分なタップ領域にする。（要件定義書 8章）
          // 画面イメージの一覧は行が詰まっているため、独立したボタンほどの
          // 高さは取らず、OS 推奨の 48 を下限とする。
          constraints: const BoxConstraints(
            minHeight: AppTheme.listRowMinHeight,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: entry.isCompleted,
                onChanged: enabled ? (_) => onToggle() : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: entry.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: entry.isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (entry.time != null || entry.isRepeating)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _subtitleFor(entry),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 行のタップは完了チェック、こちらは修正。
              // 長押しに割り当てると気づけないため、独立したボタンにする。
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: AppStrings.editOpenLabel,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitleFor(ScheduleEntry entry) {
    final parts = <String>[];

    final time = entry.time;
    if (time != null) {
      parts.add(
        time.minute > 0 ? '${time.hour}時${time.minute}分' : '${time.hour}時',
      );
    }

    switch (entry.schedule.repeat) {
      case RepeatType.none:
        break;
      case RepeatType.daily:
        parts.add(AppStrings.confirmRepeatDaily);
      case RepeatType.weekly:
        final weekday = entry.schedule.weekday;
        parts.add(
          weekday == null
              ? AppStrings.confirmRepeatWeeklyPrefix
              : '${AppStrings.confirmRepeatWeeklyPrefix}'
                  '${_weekdayNames[weekday - 1]}曜',
        );
    }

    return parts.join('  ');
  }

  static const _weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];
}
