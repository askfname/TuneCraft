import '../headstock_layout.dart';
import 'instrument.dart';

/// 吉他标准调弦 E2 A2 D3 G3 B3 E4（6->1）
class GuitarStandardInstrument implements Instrument {
  @override
  String get id => 'guitar-standard-6';

  @override
  String get name => '吉他 · 标准调弦';

  @override
  List<TuningString> get strings => const [
        TuningString(index: 6, note: 'E2', midi: 40, freq: 82.41),
        TuningString(index: 5, note: 'A2', midi: 45, freq: 110.00),
        TuningString(index: 4, note: 'D3', midi: 50, freq: 146.83),
        TuningString(index: 3, note: 'G3', midi: 55, freq: 196.00),
        TuningString(index: 2, note: 'B3', midi: 59, freq: 246.94),
        TuningString(index: 1, note: 'E4', midi: 64, freq: 329.63),
      ];

  @override
  HeadstockLayout get defaultLayout => HeadstockLayout.threePlusThree;

  // 需求：同时支持 3+3 与单侧 6 弦
  @override
  List<HeadstockLayout> get supportedLayouts =>
      const [HeadstockLayout.threePlusThree, HeadstockLayout.sixInLine];

  @override
  double get minFreq => 60;

  @override
  double get maxFreq => 500;
}

// --- 后续迭代示例（无需改 UI/引擎，只需取消注释并注册）：
// class BassStandardInstrument implements Instrument { ... 4弦 E1 A1 D2 G2 ... }
// class UkuleleStandardInstrument implements Instrument { ... G4 C4 E4 A4 ... }
