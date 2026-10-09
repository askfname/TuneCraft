import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/headstock_layout.dart';
import '../../state/tuner_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/headstock_widget.dart';
import '../widgets/meter_gauge.dart';

/// 吉他调音单页
class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen> {
  @override
  void initState() {
    super.initState();
    // 进屏自动启动调音
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(tunerProvider.notifier).start());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(tunerProvider);
    final ctl = ref.read(tunerProvider.notifier);
    final color = AppTheme.tuneColor(s.grade, s.hasSignal);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 乐器（含琴头布局）+ 自动开关
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _topRow(s, ctl),
              ),
              if (s.permissionDenied) ...[
                const SizedBox(height: 8),
                _permBanner(ctl),
              ],
              if (s.error != null && !s.permissionDenied) ...[
                const SizedBox(height: 8),
                Text('出错：${s.error}',
                    style: const TextStyle(
                        color: AppTheme.bad, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              // 横向线形指针
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 76,
                        width: double.infinity,
                        child: MeterGauge(
                          cents: s.smoothCents,
                          grade: s.grade,
                          hasSignal: s.hasSignal,
                        ),
                      ),
                      Text(
                        _hint(s),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 琴头（占满剩余高度）
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: HeadstockWidget(
                      instrument: s.instrument,
                      layout: s.layout,
                      targetIndex: s.target.index,
                      lockedIndex: s.lockedIndex,
                      grade: s.grade,
                      hasSignal: s.hasSignal,
                      onSelect: ctl.lockString,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 顶部：乐器下拉 + 自动开关（选中=自动，取消=手动）
  Widget _topRow(TunerState s, TunerController ctl) {
    final value = s.layout == HeadstockLayout.sixInLine
        ? 'guitar-6'
        : 'guitar-33';
    return Row(
      children: [
        // 无固定宽度：按内容自适应
        DropdownButton<String>(
          value: value,
          isDense: true,
          iconSize: 24,
          underline: const SizedBox.shrink(), // 去下划线
          selectedItemBuilder: (context) => const [
            Text('吉他 · 3+3双侧'),
            Text('吉他 · 单侧6弦'),
            Text('贝司'),
            Text('尤克里里'),
          ],
          items: const [
            DropdownMenuItem(
                value: 'guitar-33',
                child:
                    Text('吉他 · 3+3双侧', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(
                value: 'guitar-6',
                child:
                    Text('吉他 · 单侧6弦', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(
                value: 'bass',
                enabled: false,
                child:
                    Text('贝司 · 即将支持', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(
                value: 'ukulele',
                enabled: false,
                child: Text('尤克里里 · 即将支持',
                    overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v == 'guitar-33') {
              ctl.setLayout(HeadstockLayout.threePlusThree);
            } else if (v == 'guitar-6') {
              ctl.setLayout(HeadstockLayout.sixInLine);
            }
          },
        ),
        const Spacer(),
        // 单钮：选中=自动识别，取消选中=手动（含点弦钮锁定，钮自动弹起）
        SegmentedButton<TunerMode>(
          segments: const [
            ButtonSegment(
                value: TunerMode.auto,
                label: Text('自动'),
                icon: Icon(Icons.auto_awesome, size: 16)),
          ],
          selected: s.mode == TunerMode.auto
              ? {TunerMode.auto}
              : const <TunerMode>{},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (v) => v.contains(TunerMode.auto)
              ? ctl.unlockToAuto()
              : ctl.setMode(TunerMode.manual),
        ),
      ],
    );
  }

  Widget _permBanner(TunerController ctl) {
    return Card(
      color: AppTheme.bad.withValues(alpha: 0.12),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.mic_off, color: AppTheme.bad),
        title: const Text('未获得麦克风权限'),
        subtitle: const Text('请在系统设置中允许录音后重试'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => ctl.start(),
              child: const Text('重试'),
            ),
            TextButton(
              onPressed: openAppSettings, // 跳系统设置开麦克风权限
              child: const Text('去设置'),
            ),
          ],
        ),
      ),
    );
  }

  // 指针状态提示
  static String _hint(TunerState s) {
    if (s.hasSignal) {
      final c = s.cents!;
      if (c.abs() <= 5) return '准确 ✓ 保持不动';
      if (c < 0) return '偏低 ${c.toStringAsFixed(0)}¢ · 拧紧 ↑';
      return '偏高 +${c.toStringAsFixed(0)}¢ · 放松 ↓';
    }
    if (s.listening) return '请拨动琴弦…';
    if (s.permissionDenied) return '无麦克风权限';
    if (s.error != null) return '拾音出错，请重试';
    return '正在启动…';
  }
}
