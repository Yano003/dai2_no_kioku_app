import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/date_key.dart';
import '../../core/theme.dart';
import '../../data/models/schedule.dart';
import '../../providers.dart';
import '../calendar/calendar_screen.dart';
import '../edit/edit_schedule_screen.dart';
import '../input/input_screen.dart';
import '../settings/settings_screen.dart';
import 'day_card_view.dart';

/// ページ番号から日付を求める。
///
/// 画面イメージでは、上に明日・下に昨日が並ぶ。縦の PageView は
/// ページ番号が増えるほど下に配置されるため、番号が増えるほど日付を
/// さかのぼらせる。結果として「下へスクロール＝過去へ」という向きになる。
DateTime cardDateForIndex({
  required DateTime anchor,
  required int centerIndex,
  required int index,
}) =>
    dateOnly(anchor).subtract(Duration(days: index - centerIndex));

/// [cardDateForIndex] の逆。日付からページ番号を求める。
int cardIndexForDate({
  required DateTime anchor,
  required int centerIndex,
  required DateTime date,
}) =>
    centerIndex - dateOnly(date).difference(dateOnly(anchor)).inDays;

/// S-05 安心カード画面。
///
/// 「今日の安心カード」を中央に表示し、上下に前日・翌日のカードが
/// うっすら見える。上下スクロールで前後の日付を閲覧できる。（要件定義書 4.5）
class CardScreen extends ConsumerStatefulWidget {
  const CardScreen({super.key, this.initialDate});

  /// 通知タップやカレンダーから特定日を開く場合の日付。
  final DateTime? initialDate;

  @override
  ConsumerState<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends ConsumerState<CardScreen> {
  /// ページ番号の中心。ここから前後へ無限にスクロールできるようにする。
  static const _centerIndex = 100000;

  late final DateTime _anchorDate;
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _anchorDate = dateOnly(widget.initialDate ?? DateTime.now());
    _currentIndex = _centerIndex;
    _controller = PageController(
      initialPage: _centerIndex,
      // 前後のカードが少し覗く比率。「うっすら見える」を作る。
      viewportFraction: 0.86,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _dateForIndex(int index) => cardDateForIndex(
        anchor: _anchorDate,
        centerIndex: _centerIndex,
        index: index,
      );

  int _indexForDate(DateTime date) => cardIndexForDate(
        anchor: _anchorDate,
        centerIndex: _centerIndex,
        date: date,
      );

  Future<void> _onPageChanged(int index) async {
    setState(() => _currentIndex = index);
    // 読み込み済みの範囲を越えたら広げる。
    await ref.read(cardsProvider.notifier).ensureRange(_dateForIndex(index));
  }

  Future<void> _jumpToDate(DateTime date) async {
    final target = dateOnly(date);
    final index = _indexForDate(target);
    await ref.read(cardsProvider.notifier).ensureRange(target);
    if (!mounted) return;
    await _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// S-06 カレンダー画面を開き、選ばれた日付のカードへ移動する。
  /// （要件定義書 4.6）
  Future<void> _openCalendar() async {
    final selected = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute<DateTime>(
        builder: (_) => CalendarScreen(initialDate: _dateForIndex(_currentIndex)),
      ),
    );
    if (selected == null || !mounted) return;
    await _jumpToDate(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
                tooltip: AppStrings.settingsTitle,
              ),
            ),
            Expanded(
              child: cards.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorView(error: error),
                data: (window) => PageView.builder(
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final date = _dateForIndex(index);
                    final card = window.cardFor(date);

                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final page = _controller.hasClients &&
                                _controller.position.haveDimensions
                            ? (_controller.page ?? _currentIndex.toDouble())
                            : _currentIndex.toDouble();
                        final distance = (page - index).abs().clamp(0.0, 1.0);

                        // 要件定義書 4.5「上下に前日・翌日のカードがうっすら
                        // 見える」は、画面イメージでは前後のカードの端が覗いて
                        // いる状態として描かれている（文字は薄くなっていない）。
                        // そこで色は落とさず、少し縮めて中央を主役にする。
                        return Opacity(
                          opacity: 1.0 - distance * 0.15,
                          child: Transform.scale(
                            scale: 1.0 - distance * 0.06,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.gutter,
                          vertical: 10,
                        ),
                        child: card == null
                            ? const Center(child: CircularProgressIndicator())
                            : DayCardView(
                                card: card,
                                onToggleEntry: _toggleEntry,
                                onEditEntry: _openEdit,
                                onAcknowledge: () => _acknowledge(date),
                                // 当日夜のカードから明日のカードへ促す。
                                onOpenTomorrow: () => _jumpToDate(
                                  date.add(const Duration(days: 1)),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
            _BottomBar(
              onOpenCalendar: _openCalendar,
              onOpenInput: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const InputScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleEntry(ScheduleEntry entry) {
    ref.read(cardsProvider.notifier).toggleCompleted(entry);
  }

  void _acknowledge(DateTime date) {
    ref.read(cardsProvider.notifier).acknowledge(date);
  }

  /// S-07 修正画面を開く。（要件定義書 4.7）
  Future<void> _openEdit(ScheduleEntry entry) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditScheduleScreen(schedule: entry.schedule),
      ),
    );
  }

  /// S-08 設定画面を開く。（要件定義書 4.8）
  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onOpenCalendar, required this.onOpenInput});

  /// 横並びの見積もりに使う実測値。ボタンの左右余白・アイコン・その間隔。
  static const _labelPadding = 12.0;
  static const _iconWidth = 24.0;
  static const _iconGap = 8.0;

  /// labelLarge の文字サイズ。全角1文字の幅として扱う。
  static const _labelFontSize = 18.0;

  static const _buttonGap = 12.0;

  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenInput;

  @override
  Widget build(BuildContext context) {
    // OS の文字サイズを大きくすると、横並びでは「カレンダー」が
    // 折り返してしまう。文字を縮めず、幅が足りなければ縦に並べ替える。
    //（要件定義書 8章）
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;

    // 左右の余白を狭めて文字の場所を確保する。他の指定はテーマのまま。
    final style = ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: _labelPadding, vertical: 14),
      ),
    );

    final input = FilledButton.icon(
      onPressed: onOpenInput,
      style: style,
      icon: const Icon(Icons.mic_none_outlined),
      label: const Text(AppStrings.cardOpenInput),
    );
    final calendar = OutlinedButton.icon(
      onPressed: onOpenCalendar,
      style: style,
      icon: const Icon(Icons.calendar_month_outlined),
      label: const Text(AppStrings.cardOpenCalendar),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        8,
        AppTheme.gutter,
        16,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needed = _neededWidth(AppStrings.cardOpenInput, textScale) +
              _neededWidth(AppStrings.cardOpenCalendar, textScale) +
              _buttonGap;

          // 画面イメージに合わせ、左に「登録する」、右に「カレンダー」。
          if (needed <= constraints.maxWidth) {
            return Row(
              children: [
                Expanded(child: input),
                const SizedBox(width: _buttonGap),
                Expanded(child: calendar),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              input,
              const SizedBox(height: _buttonGap),
              calendar,
            ],
          );
        },
      ),
    );
  }

  /// [label] が折り返さずに収まるボタンの幅。
  static double _neededWidth(String label, double textScale) =>
      _labelPadding * 2 +
      _iconWidth +
      _iconGap +
      label.length * _labelFontSize * textScale;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Text(
          '$error',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
