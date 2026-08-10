/// アプリに同梱する画像などのパスを集約したファイル。
///
/// 差し替え時にこの1ファイルだけを見ればよいよう、UI 側に
/// パスの文字列リテラルを直接書かないこと。（app_strings.dart と同じ方針）
class AppAssets {
  const AppAssets._();

  /// S-02 の「話しかける」ボタンの意匠。
  ///
  /// 木須様よりご提供いただいた線画。黒一色・背景透過の PNG で、
  /// 表示側で枠の色に合わせて塗り替える前提。
  static const speakingHead = 'assets/icon_speaking_head.png';
}
