import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/theme.dart';
import '../../domain/parser/schedule_parser.dart';
import '../../providers.dart';
import '../card/card_screen.dart';
import '../confirm/confirm_screen.dart';
import 'text_input_screen.dart';

/// S-02 TOP（音声入力）。
///
/// 起動直後にこの画面を表示し、すぐに登録を開始できる。（要件定義書 4.2）
///
/// ■ 入力操作の方式（確認事項 No.1）
/// 画面イメージにあった「押しながら話す」と「長押しで文字入力へ切り替え」は
/// 同じ長押し操作にあたり両立しないため、次の方式で実装している。
/// ・音声入力：アイコンを1回タップ → 録音開始 → 無音で自動停止
/// ・文字入力：別のボタンをタップして切り替え
class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  bool _initializing = true;
  bool _available = false;
  bool _listening = false;
  String _recognized = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await ref.read(speechServiceProvider).initialize(
          onError: (message) {
            if (!mounted) return;
            setState(() {
              _listening = false;
              _errorMessage = AppStrings.errorSpeechEmpty;
            });
          },
        );
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _available = available;
    });
  }

  Future<void> _startListening() async {
    setState(() {
      _listening = true;
      _recognized = '';
      _errorMessage = null;
    });

    await ref.read(speechServiceProvider).startListening(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _recognized = result.text);
        // 無音による自動停止、または利用者が話し終えたと判断された時点。
        if (result.isFinal) _finish();
      },
    );
  }

  Future<void> _stopListening() async {
    await ref.read(speechServiceProvider).stopListening();
    if (!mounted) return;
    // 停止操作の直後は確定結果が届いていないことがあるため、
    // 手元の認識結果でそのまま進める。
    _finish();
  }

  void _finish() {
    if (!_listening) return;
    setState(() => _listening = false);

    final text = _recognized.trim();
    if (text.isEmpty) {
      // 「聞き取れませんでした」で終わらせない。（要件定義書 4.9）
      setState(() => _errorMessage = AppStrings.errorSpeechEmpty);
      return;
    }

    _openConfirm(text);
  }

  void _openConfirm(String text) {
    final parsed = ScheduleParser().parse(text);
    if (parsed.isEmpty) {
      setState(() => _errorMessage = AppStrings.errorSpeechEmpty);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmScreen(items: parsed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          child: Column(
            children: [
              // 見出しは画面の上部に置き、その上には軽くゆとりを取るだけにする。
              // 説明とアイコンは、見出しの下に残った余白の中で上下中央に置く。
              // 見出しだけを動かし、上の余白は詰める。（お客様ご指摘）
              //
              // 文字を大きくして収まらなくなったときはスクロールに切り替わる。
              // そのため中央寄せは「余白があるときだけ」効く形にしている。
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 48),
                            // この画面が何をする場所かを最初に示す見出し。
                            // 画面の主役として、カードの見出しより一段大きく取る。
                            Text(
                              AppStrings.registerScreenTitle,
                              style: theme.textTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _listening
                                          ? AppStrings.inputListening
                                          : AppStrings.inputPrompt,
                                      style: theme.textTheme.bodyLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    _MicButton(
                                      listening: _listening,
                                      enabled: !_initializing && _available,
                                      onPressed: _listening
                                          ? _stopListening
                                          : _startListening,
                                    ),
                                    const SizedBox(height: 24),
                                    if (_listening) ...[
                                      // 認識途中の文字を出して
                                      // 「聞こえている」ことを伝える。
                                      Text(
                                        _recognized,
                                        style: theme.textTheme.bodyLarge,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      // 無音での自動停止だけに頼らず、
                                      // 明示的な停止も置く。
                                      OutlinedButton(
                                        onPressed: _stopListening,
                                        child: const Text(AppStrings.inputStop),
                                      ),
                                    ] else ...[
                                      if (_errorMessage != null)
                                        Text(
                                          _errorMessage!,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                color: theme.colorScheme.error,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      if (!_initializing && !_available)
                                        Text(
                                          AppStrings.errorSpeechUnavailable,
                                          style: theme.textTheme.bodyLarge,
                                          textAlign: TextAlign.center,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openTextInput,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text(AppStrings.inputSwitchToText),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _openCard,
                child: const Text(AppStrings.inputOpenCard),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTextInput() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const TextInputScreen()),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    _openConfirm(text);
  }

  void _openCard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const CardScreen()),
    );
  }
}

/// 中央の音声アイコン。1回タップで録音を開始する。
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.enabled,
    required this.onPressed,
  });

  final bool listening;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 音声入力を表すアイコンは、初回案内「声で登録するために」で使っている
    // マイクに揃える。同じ「声で入れる」操作が画面ごとに違う絵柄で出てくると、
    // 別の機能に見えてしまうため。（お客様ご指摘）
    return Semantics(
      button: true,
      label: listening ? AppStrings.inputStop : AppStrings.inputPrompt,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: listening ? colors.primary : Colors.transparent,
            border: Border.all(
              color: enabled ? colors.primary : colors.outlineVariant,
              width: 2,
            ),
            boxShadow: listening
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: listening
                ? Icon(Icons.stop_rounded, size: 76, color: colors.onPrimary)
                : Icon(
                    Icons.mic_none_outlined,
                    size: 84,
                    color: enabled ? colors.primary : colors.outline,
                  ),
          ),
        ),
      ),
    );
  }
}
