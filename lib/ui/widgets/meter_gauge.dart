import 'package:flutter/material.dart';

import '../../core/tuning/tuning_math.dart';
import '../theme/app_theme.dart';

/// 横向线形仪表：-50¢ ~ +50¢，指针随音调左右移动，中间 0 为基准（绿=准，红=偏）
class MeterGauge extends StatelessWidget {
  final double? cents; // 已平滑值，无信号时回中
  final TuneGrade grade;
  final bool hasSignal;
  const MeterGauge({
    super.key,
    required this.cents,
    required this.grade,
    required this.hasSignal,
  });

  @override
  Widget build(BuildContext context) {
    // 平滑补间，避免指针抖动
    final target = (cents ?? 0).clamp(-50.0, 50.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target.toDouble()),
      duration: const Duration(milliseconds: 90),
      builder: (context, v, _) =>
          CustomPaint(painter: _LinearGaugePainter(v, grade, hasSignal)),
    );
  }
}

class _LinearGaugePainter extends CustomPainter {
  final double cents;
  final TuneGrade grade;
  final bool hasSignal;
  _LinearGaugePainter(this.cents, this.grade, this.hasSignal);

  static const _pad = 18.0;
  static const _trackTop = 26.0;
  static const _trackH = 14.0;

  // ¢ -> x（左 -50，右 +50）
  double _x(double c, double w) => _pad + (c + 50) / 100 * (w - 2 * _pad);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final color = AppTheme.tuneColor(grade, hasSignal);
    final trackY = _trackTop + _trackH / 2;

    // 刻度数字（-50 -25 0 +25 +50）
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final c in [-50, -25, 0, 25, 50]) {
      tp.text = TextSpan(
        text: c == 0 ? '0' : '${c > 0 ? '+' : ''}$c',
        style: TextStyle(
          color: c == 0 ? AppTheme.ok : Colors.white.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: c == 0 ? FontWeight.bold : FontWeight.normal,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(_x(c.toDouble(), w) - tp.width / 2, 2));
    }

    // 色带（按比例：红外侧 / 橙 / 绿±5居中）
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(_pad, _trackTop, w - 2 * _pad, _trackH),
      const Radius.circular(7),
    );
    canvas.save();
    canvas.clipRRect(trackRect);
    void zone(double from, double to, Color c) {
      canvas.drawRect(Rect.fromLTRB(_x(from, w), _trackTop, _x(to, w),
          _trackTop + _trackH), Paint()..color = c);
    }

    zone(-50, -15, AppTheme.bad.withValues(alpha: 0.55));
    zone(-15, -5, AppTheme.warn.withValues(alpha: 0.6));
    zone(-5, 5, AppTheme.ok.withValues(alpha: 0.8));
    zone(5, 15, AppTheme.warn.withValues(alpha: 0.6));
    zone(15, 50, AppTheme.bad.withValues(alpha: 0.55));
    // 轨道刻度（每 10¢ 一线）
    for (var c = -50; c <= 50; c += 10) {
      final major = c % 25 == 0;
      canvas.drawLine(
        Offset(_x(c.toDouble(), w), _trackTop + (major ? 1 : 4)),
        Offset(_x(c.toDouble(), w), _trackTop + _trackH - (major ? 1 : 4)),
        Paint()
          ..color = Colors.white.withValues(alpha: major ? 0.8 : 0.35)
          ..strokeWidth = major ? 1.5 : 1,
      );
    }
    canvas.restore();
    // 中线（准确位强调）
    canvas.drawLine(
      Offset(_x(0, w), _trackTop - 4),
      Offset(_x(0, w), _trackTop + _trackH + 4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2,
    );

    // 指针：竖条 + 下方三角 + 发光
    final px = _x(cents.clamp(-50, 50).toDouble(), w);
    canvas.drawCircle(
        Offset(px, trackY), 10, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(px, trackY), width: 5, height: 30),
        const Radius.circular(2.5),
      ),
      Paint()..color = color,
    );
    canvas.drawPath(
      Path()
        ..moveTo(px - 7, trackY + 15)
        ..lineTo(px + 7, trackY + 15)
        ..lineTo(px, trackY + 25)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _LinearGaugePainter old) =>
      old.cents != cents || old.grade != grade || old.hasSignal != hasSignal;
}
