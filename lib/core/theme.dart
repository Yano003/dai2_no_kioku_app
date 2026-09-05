import 'package:flutter/material.dart';

/// アプリのテーマ。
///
/// ■ デザイン方針（要件定義書 8章）
/// シンプル・直感的・ストレスフリー・エイジレス。
/// 「シニア向け」を想起させる意匠は用いない。
///
/// ■ 文字サイズ（要件定義書 第2.0版 8章）
/// デフォルトの文字は小さすぎないようにし、読みやすい標準サイズを基準とする
/// （注釈類を除く）。あわせて OS の文字サイズ設定にも追従する。
///
/// Material の既定値（本文16／補助14）はこの用途にはやや小さいため、
/// 本文系を一段引き上げている。ただし「大きな文字を前提にした高齢者向け
/// デザイン」にはしない。あくまで読みやすい標準サイズであり、
/// それ以上は利用者が OS 側で拡大できるようにする。
///
/// ■ レイアウトの原則
/// 文字が大きくなっても崩れないよう、高さを固定しない・文字は必ず
/// 折り返せるようにする・はみ出す領域はスクロールさせる、を全画面で守ること。
class AppTheme {
  const AppTheme._();

  /// 落ち着いた青緑。医療・介護を想起させる色や、子ども向けに見える
  /// 高彩度の色は避ける。
  static const _seed = Color(0xFF3E6B7E);

  /// 背景。純白より少し温かみのある色にして、長時間見ても疲れにくくする。
  static const _background = Color(0xFFFAF8F5);

  /// ボタンのタップ領域の最小サイズ。指の大きさに個人差があるため、
  /// OS の推奨（48）より大きく取る。（要件定義書 8章 アクセシビリティ）
  static const minTapSize = 56.0;

  /// カード内の予定一覧1行の最小の高さ。
  ///
  /// 画面イメージの一覧は行が詰まっているため、独立したボタンほどの高さは
  /// 取らない。ただし OS が推奨する 48 は下回らないようにする。
  static const listRowMinHeight = 48.0;

  /// 画面の左右余白。
  static const gutter = 20.0;

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(surface: _background);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,

      // ここで決めるのは「デフォルトの大きさ」であり、上限ではない。
      // OS の文字サイズ設定は Flutter が自動で掛け算するため、
      // 利用者が拡大すればここで指定した値からさらに大きくなる。
      //
      // テスト後アンケート（2026/09/04）で「文字ちょっと小さく感じてます」と
      // いう声があり、大見出しと注釈を除いて約1.1倍に引き上げた。
      // 大見出しは元から十分に大きく、注釈は小さいままでよいとの判断。
      // （クライアントご指示 2026/09/05）
      textTheme: const TextTheme(
        // 画面そのものの見出し（S-02「〈今日の安心カード〉登録」）。
        // その画面の主役として、カードの見出しより一段大きく取る。
        // ここは「大見出し」にあたるため据え置き。
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        // カードの見出し（「今日は3つ覚えておけば大丈夫です」など）25→27
        headlineSmall: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        // 21→23
        titleLarge: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        // 17→19
        titleMedium: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        // 本文。予定名などの主役の文字。18→20
        bodyLarge: TextStyle(fontSize: 20, height: 1.6),
        // 注釈類。要件上「小さすぎないように」の対象外であり、
        // 今回の拡大からも外す。
        bodyMedium: TextStyle(fontSize: 15, height: 1.6),
        // ボタンの文字。押す対象が読みにくいと操作をためらわせる。18→20
        labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 高さを固定せず最小値だけ決める。文字が大きくなれば縦に伸びる。
          minimumSize: const Size(double.infinity, minTapSize),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, minTapSize),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, minTapSize),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // 画面イメージのカードは、角丸控えめ＋細い枠線。
      // 生成り色の背景に白いカードを置くだけだと輪郭が曖昧になるため、
      // 影ではなく線で境界を示す。
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
