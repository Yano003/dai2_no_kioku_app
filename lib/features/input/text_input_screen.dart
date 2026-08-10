import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/theme.dart';

/// テキスト入力画面。
///
/// 要件定義書 2.1 の機能グループ③に対応するが、3章の画面一覧には
/// 番号が振られていないため、S-02 から遷移する独立画面として実装している。
///
/// 音声の許可が拒否された場合や、音声認識が使えない端末でも
/// 登録を続けられるようにする経路でもある。（要件定義書 4.1）
class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.textInputTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                // 話し言葉のまま入力しても解析できるため、複数行を許す。
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: AppStrings.textInputHint,
                ),
              ),
              const SizedBox(height: 16),
              for (final example in AppStrings.inputExamples)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    example,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: const Text(AppStrings.textInputConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
