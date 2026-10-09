import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunecraft/app.dart';
import 'package:tunecraft/ui/widgets/meter_gauge.dart';

void main() {
  testWidgets('自动启动', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TuneCraftApp()));
    await tester.pumpAndSettle();

    // 1. 乐器下拉默认 3+3，可切换到单侧 6 弦
    expect(find.text('吉他 · 3+3双侧'), findsOneWidget);
    await tester.tap(find.text('吉他 · 3+3双侧'));
    await tester.pumpAndSettle();
    expect(find.text('吉他 · 单侧6弦'), findsWidgets); // 下拉菜单项
    await tester.tap(find.text('吉他 · 单侧6弦'));
    await tester.pumpAndSettle();
    expect(find.text('吉他 · 单侧6弦'), findsOneWidget);

    // 2. 横向线形仪表存在
    expect(find.byType(MeterGauge), findsOneWidget);

    // 3. 琴头弦钮存在
    expect(find.text('6弦'), findsOneWidget);
    expect(find.text('1弦'), findsOneWidget);

    // 单侧布局弦序：上->下 1..6（1弦在上、6弦靠近琴颈，防倒置回归）
    final y1 = tester.getCenter(find.text('1弦')).dy;
    final y6 = tester.getCenter(find.text('6弦')).dy;
    expect(y1, lessThan(y6));

    // 4. 无弦带/开始按钮；进屏已自动 start（listening 置位 -> 提示拨弦）
    expect(find.text('开始调音'), findsNothing);
    expect(find.text('请拨动琴弦…'), findsOneWidget);

    // 自动/手动联动：点弦钮锁定（出锁徽标）-> 点自动钮解锁；
    // 再取消选中自动钮 -> 回到手动
    await tester.tap(find.text('3弦'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsOneWidget);
    await tester.tap(find.text('自动'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.text('3弦'), findsOneWidget);
    await tester.tap(find.text('自动'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });
}
