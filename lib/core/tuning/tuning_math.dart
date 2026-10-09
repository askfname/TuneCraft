import 'dart:math' as math;

/// 音分/频率换算与匹配工具（与乐器无关，可复用）
class TuningMath {
  static const double a4Freq = 440.0;
  static const int a4Midi = 69;

  /// midi -> 频率
  static double midiToFreq(int midi) =>
      a4Freq * math.pow(2, (midi - a4Midi) / 12);

  /// 频率 -> 最近 midi（浮点）
  static double freqToMidiFloat(double freq) =>
      a4Midi + 12 * (_log2(freq / a4Freq));

  static double _log2(double x) => math.log(x) / math.ln2;

  /// 实测频率相对目标频率的偏差（音分，+偏高/-偏低）
  static double centsBetween(double heardFreq, double targetFreq) {
    if (heardFreq <= 0 || targetFreq <= 0) return 0;
    return 1200 * _log2(heardFreq / targetFreq);
  }

  /// midi 音名（C/C#/D...）
  static const _names = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static String noteName(int midi) {
    final pc = midi % 12;
    final octave = (midi ~/ 12) - 1;
    return '${_names[pc]}$octave';
  }

  /// 状态判定：<=5¢准，<=15¢接近，其余偏离
  static TuneGrade grade(double centsAbs) {
    if (centsAbs <= 5) return TuneGrade.inTune;
    if (centsAbs <= 15) return TuneGrade.close;
    return TuneGrade.off;
  }
}

/// 调音状态分级
enum TuneGrade { inTune, close, off }
