import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 「話しかける」を表すアイコン。左を向いた横顔と、口元から出る音波。
///
/// 木須様よりご提供いただいた意匠に合わせて自前で描画している。
/// Material のアイコンには、音波が顔の前（左）に出るものが無いため。
///
/// フォントではなく Canvas で描いているので、太さや大きさを自由に調整でき、
/// ゴールデンテストでもそのまま描画を確認できる。
class SpeakingHeadIcon extends StatelessWidget {
  const SpeakingHeadIcon({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 5.5,
  });

  final double size;
  final Color color;

  /// 線の太さ。100×100 の座標系での値。
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SpeakingHeadPainter(color: color, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _SpeakingHeadPainter extends CustomPainter {
  _SpeakingHeadPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  /// 設計用の座標系。この 100×100 で描いたものを実サイズへ拡大する。
  static const _design = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _design;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawHead(canvas, paint);
    _drawWaves(canvas, paint);

    canvas.restore();
  }

  /// 左を向いた横顔。額 → 鼻 → 口 → あご → 首 → 後頭部 の順に閉じる。
  void _drawHead(Canvas canvas, Paint paint) {
    final path = Path()
      // 頭頂から額へ、前（左）に回り込む
      ..moveTo(57, 16)
      ..cubicTo(43, 16, 34, 28, 33, 41)
      // 鼻。輪郭の中でいちばん前に出る部分。
      ..lineTo(23, 52)
      ..lineTo(33, 56)
      // 口元のくぼみ
      ..cubicTo(33, 61, 35, 64, 39, 65)
      // あご
      ..cubicTo(41, 71, 40, 76, 37, 80)
      // 首の前側から下端へ
      ..cubicTo(44, 84, 51, 86, 58, 86)
      // 後頭部へ回り込んで閉じる
      ..cubicTo(71, 86, 79, 72, 79, 51)
      ..cubicTo(79, 30, 70, 16, 57, 16)
      ..close();

    canvas.drawPath(path, paint);
  }

  /// 口元から前方（左）へ広がる音波。3本。
  void _drawWaves(Canvas canvas, Paint paint) {
    const origin = Offset(30, 52);
    const startAngle = 143 * math.pi / 180;
    const sweepAngle = 74 * math.pi / 180;

    for (final radius in [15.0, 24.0, 33.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeakingHeadPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
