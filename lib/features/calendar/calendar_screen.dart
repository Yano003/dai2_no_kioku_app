import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/date_key.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// S-06 カレンダー画面。
///
/// 月表示のカレンダーから特定の日付を選び、その日のカードへ移動する。
/// 予定がある日には印を表示する。（要件定義書 4.6）
///
/// 選んだ日付を [Navigator.pop] の戻り値として返す。カードへの移動そのものは
/// 呼び出し元（S-05）が行う。
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, required this.initialDate});

  /// 開いたときに表示する月と、選択状態にする日付。
  final DateTime initialDate;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// 表示中の月（その月の1日）。
  late DateTime _month;

  /// 選択中の日付。
  late DateTime _selected;

  /// 日付ごとの予定件数。印の有無に使う。
  Map<DateTime, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(widget.initialDate);
    _month = DateTime(_selected.year, _selected.month);
    _loadCounts();
  }

  /// 表示中の月の予定件数を読み込む。
  ///
  /// 繰り返し予定はデータベース上に日付ごとの行を持たないため、
  /// リポジトリ側で発生を展開してから数える。
  Future<void> _loadCounts() async {
    final first = _month;
    final last = DateTime(_month.year, _month.month + 1, 0);
    final counts =
        await ref.read(scheduleRepositoryProvider).countsForRange(first, last);
    if (!mounted) return;
    setState(() => _counts = counts);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _loadCounts();
  }

  void _goToToday() {
    final today = dateOnly(DateTime.now());
    setState(() {
      _selected = today;
      _month = DateTime(today.year, today.month);
    });
    _loadCounts();
  }

  void _select(DateTime date) {
    setState(() => _selected = date);
    Navigator.of(context).pop(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calendarTitle),
        actions: [
          TextButton(
            onPressed: _goToToday,
            child: const Text(AppStrings.calendarBackToToday),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MonthHeader(
              month: _month,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            const _WeekdayHeader(),
            Expanded(
              child: _MonthGrid(
                month: _month,
                selected: _selected,
                counts: _counts,
                onSelect: _select,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「2026年8月」と前後の月への移動。
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = AppStrings.calendarMonthTitle
        .replaceAll('{year}', '${month.year}')
        .replaceAll('{month}', '${month.month}');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gutter,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: AppStrings.calendarPreviousMonth,
            iconSize: 32,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: AppStrings.calendarNextMonth,
            iconSize: 32,
          ),
        ],
      ),
    );
  }
}

/// 日〜土の見出し。
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                AppStrings.calendarWeekdayHeaders[i],
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _weekdayColor(context, i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 日曜・土曜だけ色を変える。日本のカレンダーの慣習に合わせる。
Color? _weekdayColor(BuildContext context, int columnIndex) {
  final colors = Theme.of(context).colorScheme;
  if (columnIndex == 0) return colors.error;
  if (columnIndex == 6) return colors.primary;
  return colors.onSurfaceVariant;
}

/// 月のマス目。
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final Map<DateTime, int> counts;
  final void Function(DateTime date) onSelect;

  @override
  Widget build(BuildContext context) {
    // 日曜始まりの並びにするための、月初までの空きマス数。
    // DateTime.weekday は月曜が1・日曜が7なので、7で割った余りが列番号になる。
    final leadingBlanks = month.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // OS の文字サイズ設定にマスの高さを追従させる。固定値にすると
    // 文字を大きくしたときに数字が切れてしまう。（要件定義書 8章）
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final cellHeight = (56.0 * textScale).clamp(56.0, 140.0);

    final today = dateOnly(DateTime.now());

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: cellHeight,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        if (index < leadingBlanks || index >= totalCells) {
          return const SizedBox.shrink();
        }

        final date = DateTime(month.year, month.month, index - leadingBlanks + 1);

        return _DayCell(
          date: date,
          columnIndex: index % 7,
          hasSchedule: (counts[date] ?? 0) > 0,
          isToday: isSameDate(date, today),
          isSelected: isSameDate(date, selected),
          onTap: () => onSelect(date),
        );
      },
    );
  }
}

/// 1日分のマス。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.columnIndex,
    required this.hasSchedule,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final int columnIndex;
  final bool hasSchedule;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Color? background;
    final Color? foreground;
    if (isSelected) {
      background = colors.primary;
      foreground = colors.onPrimary;
    } else if (isToday) {
      background = colors.primaryContainer;
      foreground = colors.onPrimaryContainer;
    } else {
      background = null;
      foreground = _weekdayColor(context, columnIndex);
    }

    return Semantics(
      button: true,
      selected: isSelected,
      // 日付と印をひとまとまりで読み上げる。数字だけが単独で読まれると
      // 何の数字か分からないため、内側の読み上げは抑制する。
      excludeSemantics: true,
      label: '${date.month}月${date.day}日'
          '${hasSchedule ? ' ${AppStrings.calendarHasSchedule}' : ''}',
      child: InkResponse(
        key: ValueKey('day-${toDateKey(date)}'),
        onTap: onTap,
        radius: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${date.day}',
                style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
              ),
            ),
            const SizedBox(height: 3),
            // 予定がある日の印。（要件定義書 4.6）
            SizedBox(
              height: 6,
              child: hasSchedule
                  ? Container(
                      key: ValueKey('mark-${toDateKey(date)}'),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? colors.onPrimary : colors.primary,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
