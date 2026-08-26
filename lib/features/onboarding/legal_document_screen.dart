import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme.dart';

/// 利用規約・プライバシーポリシー本文の表示画面。
///
/// 同意画面（S-01 1画面目）からのリンクで開く。ストア掲載用のページが
/// まだ無い開発段階でも中身を確認できるよう、本文はアプリ内に同梱した
/// テキストアセットから読み込む。
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(assetPath),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: SelectableText(
                snapshot.data!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          },
        ),
      ),
    );
  }
}
