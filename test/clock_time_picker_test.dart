import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:dai2_no_kioku/core/clock_time.dart';
import 'package:dai2_no_kioku/core/theme.dart';
import 'package:dai2_no_kioku/core/widgets/clock_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 時刻を選ぶダイアログ。
///
/// 時計盤（Material 既定の showTimePicker）が「一見では分かりにくい」と
/// テスト後アンケート（2026/09/04）で挙がったため、数字を上下に動かして
/// 選ぶ形に置き換えた。（クライアントご指示 2026/09/05）

/// 1行の高さ。widget 側の _itemExtent と合わせる。
const _itemExtent = 52.0;

void main() {
  testWidgets('初期値のまま決定すると、その時刻が返る', (tester) async {
    ClockTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showClockTimePicker(
                context: context,
                initial: const ClockTime(9, 30),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.timePickerConfirm));
    await tester.pumpAndSettle();

    expect(result, const ClockTime(9, 30));
  });

  testWidgets('やめると何も返さない', (tester) async {
    ClockTime? result;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showClockTimePicker(
                  context: context,
                  initial: const ClockTime(9, 30),
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.timePickerCancel));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(result, isNull);
  });

  testWidgets('時の列を動かすと選んだ時刻が変わる', (tester) async {
    ClockTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showClockTimePicker(
                context: context,
                initial: const ClockTime(9, 0),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 上へ動かすと後ろの数字が出てくる。2行分で 9時 → 11時。
    await tester.drag(
      find.byType(ListWheelScrollView).first,
      const Offset(0, -_itemExtent * 2),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.timePickerConfirm));
    await tester.pumpAndSettle();

    expect(result?.hour, 11);
    expect(result?.minute, 0);
  });

  testWidgets('分の列は時の列と別に動く', (tester) async {
    ClockTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showClockTimePicker(
                context: context,
                initial: const ClockTime(9, 0),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(ListWheelScrollView).last,
      const Offset(0, -_itemExtent * 5),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.timePickerConfirm));
    await tester.pumpAndSettle();

    expect(result?.hour, 9, reason: '時の列は動かしていない');
    expect(result?.minute, 5);
  });

  testWidgets('0時をまたいで戻せる', (tester) async {
    // 0時と23時が地続きになっているため、行き過ぎても戻せる。
    ClockTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showClockTimePicker(
                context: context,
                initial: const ClockTime(0, 0),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 下へ1行分戻すと 0時 の手前、つまり 23時。
    await tester.drag(
      find.byType(ListWheelScrollView).first,
      const Offset(0, _itemExtent),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.timePickerConfirm));
    await tester.pumpAndSettle();

    expect(result?.hour, 23);
  });
}
