import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../clock_time.dart';

/// 時刻を選ぶダイアログ。
///
/// Material 既定の [showTimePicker] は時計盤で、テスト後アンケート
/// （2026/09/04）で「時間設定が難しい」「一見では分かりにくい」という声が
/// 挙がった。数字を上下に動かして選ぶ形に置き換えている。
/// （クライアントご指示 2026/09/05）
///
/// アプリ内で時刻を選ぶ場面（予定の時刻・お知らせの時刻・起床就寝の時刻）は
/// すべてここを通す。場面ごとに選び方が変わると迷わせるため。
///
/// 選ばれなければ null を返す。
Future<ClockTime?> showClockTimePicker({
  required BuildContext context,
  required ClockTime initial,
}) =>
    showDialog<ClockTime>(
      context: context,
      builder: (_) => _ClockTimePickerDialog(initial: initial),
    );

/// 1行の高さ。指で押さえやすい大きさを保つ。
const _itemExtent = 52.0;

/// 数字ひと列の幅。
const _wheelWidth = 96.0;

class _ClockTimePickerDialog extends StatefulWidget {
  const _ClockTimePickerDialog({required this.initial});

  final ClockTime initial;

  @override
  State<_ClockTimePickerDialog> createState() => _ClockTimePickerDialogState();
}

/// 分の刻み。予定の時刻に1分単位が要る場面はほとんど無く、刻みを粗くする
/// ほど選ぶ手数が減る。（クライアントご指示 2026/09/07）
const _minuteStep = 5;

final _hourValues = List<int>.generate(24, (index) => index);

/// 分の選択肢。[_minuteStep] 刻みに、初期値がその倍数でなければそれを足す。
///
/// 「9時7分」のように声から入った時刻を、ダイアログを開いただけで
/// 勝手に丸めてしまわないようにするため。
List<int> _minuteValuesFor(int initial) {
  final values = <int>{
    for (var minute = 0; minute < 60; minute += _minuteStep) minute,
    initial,
  }.toList()
    ..sort();
  return values;
}

class _ClockTimePickerDialogState extends State<_ClockTimePickerDialog> {
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;
  late final List<int> _minuteValues = _minuteValuesFor(widget.initial.minute);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text(AppStrings.timePickerTitle),
      // 文字を大きくしても収まるよう、内容の幅は成り行きに任せる。
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.timePickerHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            // 選んでいる行の上下に2行ずつ見えるようにする。前後が見えていないと
            // 動かせることに気づけない。
            height: _itemExtent * 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 選択位置の帯。時と分をまたいで1本にする。
                IgnorePointer(
                  child: Container(
                    height: _itemExtent,
                    width: _wheelWidth * 2,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Wheel(
                      values: _hourValues,
                      initialValue: _hour,
                      suffix: AppStrings.timePickerHourSuffix,
                      onChanged: (value) => setState(() => _hour = value),
                    ),
                    _Wheel(
                      values: _minuteValues,
                      initialValue: _minute,
                      suffix: AppStrings.timePickerMinuteSuffix,
                      onChanged: (value) => setState(() => _minute = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.timePickerCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ClockTime(_hour, _minute)),
          child: const Text(AppStrings.timePickerConfirm),
        ),
      ],
    );
  }
}

/// 数字ひと列分の輪。[values] を順に、端までいったら先頭に戻って送れる。
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.values,
    required this.initialValue,
    required this.suffix,
    required this.onChanged,
  });

  /// 上から順に並べる値。時なら0〜23、分なら5刻み。
  final List<int> values;

  final int initialValue;

  /// 「時」「分」。数字の右に添えて、何を選んでいるかを示す。
  final String suffix;

  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(
    // 一覧に無い値を渡された場合でも先頭から始めて破綻させない。
    initialItem: widget.values.indexOf(widget.initialValue).clamp(0, 1 << 30),
  );

  late int _selected = widget.initialValue;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _wheelWidth,
      height: _itemExtent * 5,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: _itemExtent,
        // 平らに近い見え方にする。曲がりが強いと端の数字が読みにくい。
        diameterRatio: 2.2,
        perspective: 0.002,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          final value = widget.values[index % widget.values.length];
          setState(() => _selected = value);
          widget.onChanged(value);
        },
        // 先頭と末尾が地続きになり、行き過ぎても戻せる。
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (final value in widget.values)
              _Item(
                value: value,
                suffix: widget.suffix,
                selected: value == _selected,
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.value,
    required this.suffix,
    required this.selected,
  });

  final int value;
  final String suffix;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        '$value$suffix',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
