import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tuning/tuning_math.dart';
import '../../domain/headstock_layout.dart';
import '../../domain/instruments/instrument.dart';
import '../theme/app_theme.dart';

/// 弦钮几何（Painter 与可点击按钮共用，保证对齐）
/// post=弦轴中心，knob=旋钮中心（可点击圆钮）
class _PegGeom {
  final TuningString string;
  final Offset post;
  final Offset knob;
  const _PegGeom(this.string, this.post, this.knob);
}

/// 抽象琴头 + 部分琴颈：木纹头体、金属弦轴、弦钮，点击弦钮手动选弦
/// 支持 [HeadstockLayout.threePlusThree] 与 [HeadstockLayout.sixInLine]
/// 弦序（上->下，顶端->琴颈）：3+3 左列 D/A/E、右列 G/B/E；单侧 1..6（旋钮在左）
class HeadstockWidget extends StatelessWidget {
  final Instrument instrument;
  final HeadstockLayout layout;
  final int targetIndex; // 当前判定弦（自动=识别，手动=锁定）
  final int? lockedIndex; // 手动锁定弦
  final TuneGrade grade;
  final bool hasSignal;
  final void Function(int stringIndex) onSelect;

  const HeadstockWidget({
    super.key,
    required this.instrument,
    required this.layout,
    required this.targetIndex,
    required this.lockedIndex,
    required this.grade,
    required this.hasSignal,
    required this.onSelect,
  });

  // 琴枕高度占比（下方为琴颈区）
  static const double nutFrac = 0.80;
  // 单侧布局琴枕宽度占比（弦扇基准）
  static const double sixNutWFactor = 0.34;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final pegs = _layoutPegs(size);
      // 钮径按行距自适应，保证小屏不重叠
      final step = layout == HeadstockLayout.sixInLine
          ? size.height * 0.128
          : size.height * 0.22;
      final d = (step - 18).clamp(30.0, 52.0);
      return Stack(
        children: [
          CustomPaint(
            size: size,
            painter: _HeadstockPainter(
              layout: layout,
              pegs: pegs,
              targetIndex: targetIndex,
              grade: grade,
              hasSignal: hasSignal,
            ),
          ),
          for (final p in pegs) _pegButton(p, d),
        ],
      );
    });
  }

  // 弦钮/弦轴坐标（低音弦靠近琴颈；单侧弦轴跟随各自琴弦，无交叉）
  List<_PegGeom> _layoutPegs(Size size) {
    final cx = size.width / 2;
    final strings = instrument.strings;
    TuningString byIdx(int i) => strings.firstWhere((e) => e.index == i);
    if (layout == HeadstockLayout.sixInLine) {
      // 弦轴 = 各弦琴枕点向左平移固定量，弦近乎直上，互不交叉
      final nutW = size.width * sixNutWFactor;
      final pegs = <_PegGeom>[];
      for (var k = 1; k <= 6; k++) {
        final t = (k - 1) / 5; // k=1:0（最上）, k=6:1（最下，近琴颈）
        final nutX = cx + (0.5 - t) * nutW * 0.8; // 1弦右，6弦左
        final post = Offset(
          nutX - size.width * 0.06,
          size.height * (0.06 + 0.64 * t),
        );
        pegs.add(_PegGeom(byIdx(k), post, post + Offset(-size.width * 0.13, 0)));
      }
      return pegs;
    }
    // 3+3：左列上->下 D/A/E，右列上->下 G/B/E（低音弦靠近琴颈）
    const leftIdx = [4, 5, 6], rightIdx = [3, 2, 1];
    final bodyW = _bodyW(size);
    final postLx = cx - bodyW / 2 + 26, postRx = cx + bodyW / 2 - 26;
    final knobLx = cx - size.width * 0.32, knobRx = cx + size.width * 0.32;
    return [
      for (var i = 0; i < 3; i++)
        _PegGeom(byIdx(leftIdx[i]),
            Offset(postLx, size.height * (0.14 + 0.22 * i)),
            Offset(knobLx, size.height * (0.14 + 0.22 * i))),
      for (var i = 0; i < 3; i++)
        _PegGeom(byIdx(rightIdx[i]),
            Offset(postRx, size.height * (0.14 + 0.22 * i)),
            Offset(knobRx, size.height * (0.14 + 0.22 * i))),
    ];
  }

  static double _bodyW(Size size) => size.width * 0.48;

  Widget _pegButton(_PegGeom p, double d) {
    final isTarget = p.string.index == targetIndex;
    final isLocked = p.string.index == lockedIndex;
    final color = AppTheme.tuneColor(grade, hasSignal);
    return Positioned(
      left: p.knob.dx - d / 2,
      top: p.knob.dy - d / 2,
      width: d,
      height: d + 16,
      child: GestureDetector(
        onTap: () => onSelect(p.string.index),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none, // 锁定徽标允许压边，不参与布局
              children: [
                Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E242E),
                    border: Border.all(
                      color: isTarget
                          ? color
                          : Colors.white.withValues(alpha: 0.25),
                      width: isTarget ? 3 : 1.5,
                    ),
                    boxShadow: isTarget && hasSignal
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 1)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      p.string.note.replaceAll(RegExp(r'[0-9]'), ''),
                      style: TextStyle(
                        color: isTarget ? color : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                if (isLocked)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0F1115), width: 1.5),
                      ),
                      child: const Icon(Icons.lock,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              '${p.string.index}弦', // 固定短文本，窄钮不换行
              style: TextStyle(
                fontSize: 10,
                color: isTarget ? color : AppTheme.textDim,
                fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 琴头体 + 琴颈 + 弦轴 + 琴弦（抽象几何，圆角/渐变/粗细对比）
class _HeadstockPainter extends CustomPainter {
  final HeadstockLayout layout;
  final List<_PegGeom> pegs;
  final int targetIndex;
  final TuneGrade grade;
  final bool hasSignal;

  _HeadstockPainter({
    required this.layout,
    required this.pegs,
    required this.targetIndex,
    required this.grade,
    required this.hasSignal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final nutY = size.height * HeadstockWidget.nutFrac;
    final six = layout == HeadstockLayout.sixInLine;
    final nutW = six
        ? size.width * HeadstockWidget.sixNutWFactor
        : HeadstockWidget._bodyW(size) * 0.95;

    // 琴头体
    if (six) {
      _paintSlantedBody(canvas, size, cx, nutY);
    } else {
      final bodyW = HeadstockWidget._bodyW(size);
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - bodyW / 2, size.height * 0.045,
            cx + bodyW / 2, nutY + 2),
        const Radius.circular(34),
      );
      _paintWood(canvas, bodyRect.outerRect, bodyRect);
    }

    // 部分琴颈（梯形指板 + 品丝 + 镶嵌点）
    final neckTopW = nutW * 0.66, neckBotW = nutW * 0.88;
    final neck = Path()
      ..moveTo(cx - neckTopW / 2, nutY)
      ..lineTo(cx + neckTopW / 2, nutY)
      ..lineTo(cx + neckBotW / 2, size.height)
      ..lineTo(cx - neckBotW / 2, size.height)
      ..close();
    canvas.drawPath(
      neck,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3A2A1C), Color(0xFF1B130C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(
            cx - neckBotW, nutY, cx + neckBotW, size.height)),
    );
    // 品丝线
    for (final t in [0.3, 0.58, 0.84]) {
      final y = nutY + (size.height - nutY) * t;
      final halfW = (neckTopW + (neckBotW - neckTopW) * t) / 2;
      canvas.drawLine(
        Offset(cx - halfW, y),
        Offset(cx + halfW, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..strokeWidth = 2,
      );
    }
    // 镶嵌点
    canvas.drawCircle(
      Offset(cx, nutY + (size.height - nutY) * 0.58),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );

    // 琴枕（头颈分界白条）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, nutY), width: nutW, height: 9),
        const Radius.circular(4.5),
      ),
      Paint()..color = const Color(0xFFE8E0D0),
    );

    // 琴弦：琴枕 -> 弦轴（低音粗、高音细），枕下向琴颈淡出一段
    for (final p in pegs) {
      final isTarget = p.string.index == targetIndex;
      final w = _stringWidth(p.string.index);
      final paint = Paint()
        ..color = isTarget && hasSignal
            ? AppTheme.tuneColor(grade, true)
            : Colors.white.withValues(alpha: isTarget ? 0.95 : 0.55)
        ..strokeWidth = w + (isTarget ? 1.2 : 0)
        ..strokeCap = StrokeCap.round;
      final nutX = cx + _nutOffset(p.string.index, nutW);
      canvas.drawLine(Offset(nutX, nutY - 4), p.post, paint);
      canvas.drawLine(
        Offset(nutX, nutY + 4),
        Offset(nutX, nutY + size.height * 0.10),
        Paint()
          ..color = paint.color.withValues(alpha: 0.30)
          ..strokeWidth = paint.strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // 轴杆 + 外端钮帽
    for (final p in pegs) {
      final dir = p.knob - p.post;
      final unit = dir / dir.distance;
      canvas.drawLine(
        p.post,
        p.knob,
        Paint()
          ..color = const Color(0xFF9AA3AF)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
      // 钮帽（旋钮外端，抽象圆钮）
      final capC = p.knob + unit * 30;
      canvas.drawCircle(capC, 6.5, Paint()..color = const Color(0xFF7C8794));
      canvas.drawCircle(
        capC,
        6.5,
        Paint()
          ..color = const Color(0xFF4A5260)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 弦轴（金属盘，压住弦端）
    for (final p in pegs) {
      canvas.drawCircle(p.post, 10, Paint()..color = const Color(0xFFC9D2DD));
      canvas.drawCircle(
        p.post,
        10,
        Paint()
          ..color = const Color(0xFF7C8794)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(p.post, 3.5, Paint()..color = const Color(0xFF20262E));
      canvas.drawCircle(
        p.post + const Offset(-3, -3),
        1.5,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }
  }

  // 单侧头体：左侧斜角四边形（弦轴顺斜角内侧排列）
  void _paintSlantedBody(Canvas canvas, Size size, double cx, double nutY) {
    // 按 y 取最上/最下弦轴（不依赖列表顺序，防倒置）
    var pTop = pegs.first.post, pBot = pegs.first.post;
    for (final p in pegs) {
      if (p.post.dy < pTop.dy) pTop = p.post;
      if (p.post.dy > pBot.dy) pBot = p.post;
    }
    final d = pBot - pTop;
    final len = d.distance;
    final ux = d.dx / len, uy = d.dy / len;
    // 斜角线：过弦轴列，向左偏 28
    double slantX(double y) => pTop.dx + ux / uy * (y - pTop.dy);
    final double topY = math.max(pTop.dy - 34, 4).toDouble(); // 防顶部出界
    final rightX = cx + size.width * 0.20;
    // 四角圆角（与 3+3 圆角头体风格统一）
    final path = _roundedPoly(
      [
        Offset(slantX(topY) - 28, topY),
        Offset(rightX, topY),
        Offset(rightX, nutY + 2),
        Offset(slantX(nutY + 2) - 28, nutY + 2),
      ],
      16,
    );
    final bounds =
        Rect.fromLTRB(slantX(topY) - 28, topY, rightX, nutY + 2);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8A5A33), Color(0xFF4A2E1B), Color(0xFF2A1A10)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // 凸多边形圆角化（每角用二次贝塞尔倒圆，半径受最短邻边钳制）
  Path _roundedPoly(List<Offset> pts, double r) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final prev = pts[(i - 1 + pts.length) % pts.length];
      final curr = pts[i];
      final next = pts[(i + 1) % pts.length];
      final d1 = curr - prev, d2 = next - curr;
      final rr = math.min(r, math.min(d1.distance, d2.distance) / 2);
      final p1 = curr - d1 / d1.distance * rr;
      final p2 = curr + d2 / d2.distance * rr;
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  // 木纹填充 + 高光描边
  void _paintWood(Canvas canvas, Rect shaderRect, RRect rect) {
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8A5A33), Color(0xFF4A2E1B), Color(0xFF2A1A10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(shaderRect),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // 弦粗：6弦最粗
  double _stringWidth(int index) => switch (index) {
        6 => 4.2,
        5 => 3.6,
        4 => 3.0,
        3 => 2.3,
        2 => 1.8,
        _ => 1.5,
      };

  // 枕上横向分布（-0.5..0.5）
  double _nutOffset(int index, double nutW) {
    // index 6->1 映射 -0.4..0.4
    final t = (6 - index) / 5; // 6:0, 1:1
    return (t - 0.5) * nutW * 0.8;
  }

  @override
  bool shouldRepaint(covariant _HeadstockPainter old) =>
      old.targetIndex != targetIndex ||
      old.grade != grade ||
      old.hasSignal != hasSignal ||
      old.layout != layout;
}
