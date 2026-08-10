import 'package:dai2_no_kioku/core/app_identity.dart';
import 'package:dai2_no_kioku/core/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// アプリ名とタグラインが1箇所から供給されていることの確認。
///
/// アプリ名は 2026年8月7日に「キオクヲ」で確定。名称を変更する際に
/// 画面側へ直書きした文字列が残っていると差し替え漏れになるため、
/// 参照が [AppIdentity] に集約されていることをここで固定する。
void main() {
  test('アプリ名とタグラインが確定値である', () {
    expect(AppIdentity.displayName, 'キオクヲ');
    expect(AppIdentity.tagline, '思い出せる安心が、自信になる。');
  });

  test('画面が参照する文言は AppIdentity から供給される', () {
    // AppStrings 側に文字列を直書きすると、名称変更時に2箇所直す必要が出る。
    expect(AppStrings.appName, same(AppIdentity.displayName));
    expect(AppStrings.tagline, same(AppIdentity.tagline));
  });

  test('旧名称が文言に残っていない', () {
    expect(AppStrings.appName, isNot(contains('第2のキオク')));
  });
}
