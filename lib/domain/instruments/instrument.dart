import '../headstock_layout.dart';

/// 单根弦定义（index：吉他习惯 6=最低音 ~ 1=最高音）
class TuningString {
  final int index;
  final String note; // E2
  final int midi;
  final double freq; // 标准频率
  const TuningString({
    required this.index,
    required this.note,
    required this.midi,
    required this.freq,
  });
}

/// 乐器抽象：新增乐器只需实现此类并注册
abstract class Instrument {
  String get id; // 'guitar-standard'
  String get name; // '吉他 · 标准调弦'
  List<TuningString> get strings; // 按 index 降序（6->1）存放
  HeadstockLayout get defaultLayout;
  List<HeadstockLayout> get supportedLayouts;
  double get minFreq; // 检音下限（用于 YIN 裁剪）
  double get maxFreq;
}
