import 'dart:io';

import 'package:dai2_no_kioku/core/app_config.dart';
import 'package:dai2_no_kioku/core/theme.dart';
import 'package:dai2_no_kioku/data/models/schedule.dart';
import 'package:dai2_no_kioku/data/schedule_repository.dart';
import 'package:dai2_no_kioku/domain/card/day_card.dart';
import 'package:dai2_no_kioku/domain/parser/parsed_schedule.dart';
import 'package:dai2_no_kioku/features/card/day_card_view.dart';
import 'package:dai2_no_kioku/features/confirm/confirm_screen.dart';
import 'package:dai2_no_kioku/features/input/input_screen.dart';
import 'package:dai2_no_kioku/providers.dart';
import 'package:dai2_no_kioku/services/notification_service.dart';
import 'package:dai2_no_kioku/services/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実際の描画を PNG に書き出して、画面イメージと目視で突き合わせるための
/// テスト。`flutter test --update-goldens test/golden_test.dart` で
/// test/goldens/ に画像が生成される。
///
/// 通常のテスト実行では既存画像との比較になるため、意図した見た目の変更を
/// 入れたときは --update-goldens で更新すること。
///
/// テスト環境には日本語フォントが無く、そのままでは文字が豆腐になる。
/// プラットフォームごとに Noto Sans JP のパスを解決して読み込む。
const _fontFamily = 'NotoSansJP';

String? _resolveFontPath() {
  if (Platform.isWindows) return r'C:\Windows\Fonts\NotoSansJP-VF.ttf';
  if (Platform.isMacOS) {
    const candidates = [
      '/Library/Fonts/NotoSansJP-VF.ttf',
      '/Library/Fonts/NotoSansJP.ttf',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
  }
  return null;
}

final _cardDate = DateTime(2026, 7, 21);

ScheduleEntry _entry(
  String title, {
  bool completed = false,
  ClockTime? time,
  DateTime? date,
}) {
  final on = date ?? _cardDate;
  return ScheduleEntry(
    schedule: Schedule(
      id: title,
      title: title,
      baseDate: on,
      time: time,
      repeat: RepeatType.none,
      createdAt: on,
    ),
    date: on,
    isCompleted: completed,
  );
}

DayCard _card({
  required CardVariant variant,
  required int dayOffset,
  DateTime? date,
  List<ScheduleEntry> entries = const [],
}) =>
    DayCard(
      date: date ?? _cardDate,
      entries: entries,
      variant: variant,
      acknowledged: false,
      dayOffset: dayOffset,
    );

ThemeData get _theme {
  final base = AppTheme.light;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: _fontFamily),
  );
}

Widget _frame(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme,
    home: Scaffold(
      backgroundColor: AppTheme.light.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: child,
        ),
      ),
    ),
  );
}

/// 画面まるごとを撮る場合。Scaffold は画面側が持つ。
Widget _screenFrame(Widget screen) {
  return ProviderScope(
    overrides: [
      speechServiceProvider.overrideWithValue(_FakeSpeechService()),
      notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
      scheduleRepositoryProvider.overrideWithValue(_FakeScheduleRepository()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: screen,
    ),
  );
}

class _FakeSpeechService extends SpeechService {
  @override
  Future<bool> initialize({void Function(String error)? onError}) async => true;
}

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> rescheduleAll({DateTime? now}) async {}

  @override
  Future<bool> areNotificationsEnabled() async => true;
}

class _FakeScheduleRepository extends ScheduleRepository {
  @override
  Future<Map<DateTime, int>> remainingCapacityForDates(
    Iterable<DateTime> dates,
  ) async =>
      {for (final date in dates) date: AppConfig.maxSchedulesPerDay};

  @override
  Future<Map<DateTime, List<ScheduleEntry>>> entriesForRange(
    DateTime from,
    DateTime to,
  ) async =>
      {};

  @override
  Future<Set<DateTime>> acknowledgedDates(DateTime from, DateTime to) async =>
      {};
}

/// Image.asset は非同期に読み込まれるため、そのまま撮ると画像が写らない。
/// 実際の I/O を許す runAsync の中で読み込ませてから撮影する。
Future<void> _loadImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _shoot(
  WidgetTester tester,
  Widget child,
  String name, {
  Size size = const Size(390, 760),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_frame(child));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

Future<void> _shootScreen(
  WidgetTester tester,
  Widget screen,
  String name, {
  Size size = const Size(390, 760),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_screenFrame(screen));
  await tester.pumpAndSettle();
  await _loadImages(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    final fontPath = _resolveFontPath();
    if (fontPath != null) {
      final bytes = await File(fontPath).readAsBytes();
      final loader = FontLoader(_fontFamily)
        ..addFont(
            Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
      await loader.load();
    }
  });

  testWidgets('当日朝のカード', (tester) async {
    await _shoot(
      tester,
      DayCardView(
        card: _card(
          variant: CardVariant.morning,
          dayOffset: 0,
          entries: [
            _entry('朝食後に薬'),
            _entry('母さんに電話する'),
            _entry('帰りに牛乳を買う'),
            _entry('税金の支払い'),
          ],
        ),
        onToggleEntry: (_) {},
        onEditEntry: (_) {},
        onAcknowledge: () {},
      ),
      'card_morning',
    );
  });

  testWidgets('前日夜のカード', (tester) async {
    await _shoot(
      tester,
      DayCardView(
        card: _card(
          variant: CardVariant.previousNight,
          dayOffset: 1,
          date: DateTime(2026, 7, 22),
          entries: [
            _entry('朝食後に薬', date: DateTime(2026, 7, 22)),
            _entry('燃えないゴミ', date: DateTime(2026, 7, 22)),
            _entry(
              '会社の飲み会',
              time: const ClockTime(19, 0),
              date: DateTime(2026, 7, 22),
            ),
          ],
        ),
        onToggleEntry: (_) {},
        onEditEntry: (_) {},
        onAcknowledge: () {},
      ),
      'card_previous_night',
    );
  });

  testWidgets('当日日中のカード', (tester) async {
    await _shoot(
      tester,
      DayCardView(
        card: _card(
          variant: CardVariant.daytime,
          dayOffset: 0,
          entries: [
            _entry('朝食後に薬', completed: true),
            _entry('母さんに電話する'),
            _entry('帰りに牛乳を買う', completed: true),
            _entry('税金の支払い'),
          ],
        ),
        onToggleEntry: (_) {},
        onEditEntry: (_) {},
        onAcknowledge: () {},
      ),
      'card_daytime',
    );
  });

  testWidgets('前日夜のカード（予定なし）', (tester) async {
    // 「明日の予定はありません。」だけを出し、空の一覧は置かない。
    // （お客様ご指摘 2026/08/17）
    await _shoot(
      tester,
      DayCardView(
        card: _card(variant: CardVariant.previousNight, dayOffset: 1),
        onToggleEntry: (_) {},
        onEditEntry: (_) {},
        onAcknowledge: () {},
      ),
      'card_previous_night_empty',
    );
  });

  testWidgets('S-02 TOP（音声入力）', (tester) async {
    await _shootScreen(tester, const InputScreen(), 'screen_input');
  });

  testWidgets('S-03 登録確認（複数の日にまたがる発話）', (tester) async {
    // 画面イメージの4つの発話は、実際には別々の日の予定になる。
    // 日付ごとにカードが分かれることを確認する。
    await _shootScreen(
      tester,
      ConfirmScreen(
        items: [
          ParsedSchedule(
            title: '朝食後に薬',
            sourceText: '毎日、朝食後に薬',
            date: DateTime(2026, 7, 21),
            repeat: RepeatType.daily,
            dateWasSpecified: true,
          ),
          ParsedSchedule(
            title: '帰りに牛乳を買う',
            sourceText: '明日、帰りに牛乳を買う',
            date: DateTime(2026, 7, 21),
            dateWasSpecified: true,
          ),
          ParsedSchedule(
            title: '母さんに電話',
            sourceText: '今度の月曜、母さんに電話',
            date: DateTime(2026, 7, 27),
            dateWasSpecified: true,
          ),
        ],
      ),
      'screen_confirm',
    );
  });
}
