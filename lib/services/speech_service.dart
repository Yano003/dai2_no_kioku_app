import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_config.dart';

/// 音声認識の状態。
enum SpeechStatus {
  /// 未初期化。
  idle,

  /// 録音中。
  listening,

  /// 録音を終えて結果が確定した。
  done,

  /// 音声認識が使えない（許可されていない・端末が非対応）。
  unavailable,
}

/// 音声認識の結果。
class SpeechResult {
  const SpeechResult({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

/// 端末標準の音声認識を扱う。（要件定義書 10章 前提2）
///
/// ■ プライバシーに関する注意
/// [AppConfig.speechRecognitionMode] が [SpeechRecognitionMode.preferAccuracy]
/// の場合、音声データは OS の音声認識機能（iOS は Apple、Android は
/// Google の音声認識サービス）へ送信され得る。アプリ自身は音声も文字起こしも
/// 外部へ送信しないが、「一切外部に出ない」わけではない。
/// プライバシーポリシーの記載と、ストアのデータ開示の内容をこの設定と
/// 必ず一致させること。
///
/// [SpeechRecognitionMode.forceOnDevice] にすると端末内処理に限定できるが、
/// 端末が日本語のオンデバイス認識に対応していない場合、認識自体が失敗する。
class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _available = false;
  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  /// 音声認識を初期化する。使えない端末でも例外を投げず false を返す。
  Future<bool> initialize({void Function(String error)? onError}) async {
    try {
      _available = await _speech.initialize(
        onError: (error) {
          debugPrint('音声認識エラー: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
        onStatus: (status) => debugPrint('音声認識の状態: $status'),
      );
    } catch (error) {
      debugPrint('音声認識の初期化に失敗しました: $error');
      _available = false;
    }
    return _available;
  }

  /// 録音を開始する。
  ///
  /// 無音での自動停止までの時間は既定より長く取る。OS 既定の無音判定は、
  /// ゆっくり話す人や言い淀む人の発話の途中で切れてしまうため。
  /// あわせて画面には明示的な停止ボタンを置くこと。（要件定義書 4.2）
  Future<void> startListening({
    required void Function(SpeechResult result) onResult,
  }) async {
    if (!_available) return;

    await _speech.listen(
      onResult: (result) => onResult(
        SpeechResult(
          text: result.recognizedWords,
          isFinal: result.finalResult,
        ),
      ),
      listenOptions: SpeechListenOptions(
        localeId: AppConfig.speechLocaleId,
        // 認識途中の文字を表示して「聞こえている」ことを伝える。
        partialResults: true,
        pauseFor: AppConfig.speechPauseFor,
        listenFor: AppConfig.speechListenFor,
        onDevice:
            AppConfig.speechRecognitionMode == SpeechRecognitionMode.forceOnDevice,
        cancelOnError: false,
      ),
    );
  }

  /// 録音を止めて、それまでの認識結果を確定する。
  Future<void> stopListening() async {
    if (_speech.isListening) await _speech.stop();
  }

  /// 録音を中止して結果を破棄する。
  Future<void> cancelListening() async {
    if (_speech.isListening) await _speech.cancel();
  }
}
