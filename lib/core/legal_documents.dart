/// 利用規約・プライバシーポリシーの本文アセットへの参照。
///
/// 本文そのものは `assets/legal/` 配下のテキストファイルに置き、この
/// ファイルではパスだけを集約する。確定文言が届いたら、該当ファイルの
/// 差し替えだけで全画面に反映される（[AppStrings] と同じ方針）。
library;

class LegalDocuments {
  const LegalDocuments._();

  static const termsOfServiceAsset = 'assets/legal/terms_of_service.txt';
  static const privacyPolicyAsset = 'assets/legal/privacy_policy.txt';
}
