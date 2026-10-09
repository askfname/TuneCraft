import 'dart:math' as math;
import 'pitch_detector.dart';

/// YIN 基频检测（纯 Dart，Android/iOS 表现一致）
/// 参考：de Cheveigne & Kawahara, YIN (2002)，阈值法 + 抛物线插值
class YinPitchDetector implements PitchDetector {
  final double threshold; // 归一化阈值，吉他建议 0.10
  final double minFreq; // 最低可检
  final double maxFreq; // 最高可检
  final double silenceRms; // 低于此视为静音

  YinPitchDetector({
    this.threshold = 0.10,
    this.minFreq = 50,
    this.maxFreq = 1200,
    this.silenceRms = 0.02,
  });

  @override
  PitchResult? detect(List<double> samples, int sampleRate) {
    final n = samples.length;
    if (n < 64) return null;

    // 音量门限：静音直接返回空，避免指针乱跳
    var sumSq = 0.0;
    for (final s in samples) {
      sumSq += s * s;
    }
    final rms = math.sqrt(sumSq / n);
    if (rms < silenceRms) return null;

    final maxTau = (sampleRate / minFreq).floor().clamp(2, n ~/ 2);
    final minTau = (sampleRate / maxFreq).floor().clamp(2, maxTau - 1);

    // 差函数
    final yin = List<double>.filled(maxTau + 1, 0);
    for (var tau = 1; tau <= maxTau; tau++) {
      var d = 0.0;
      for (var i = 0; i + tau < n; i++) {
        final delta = samples[i] - samples[i + tau];
        d += delta * delta;
      }
      yin[tau] = d;
    }
    // 累积均值归一化
    var running = 0.0;
    yin[0] = 1;
    for (var tau = 1; tau <= maxTau; tau++) {
      running += yin[tau];
      yin[tau] = yin[tau] * tau / running;
    }
    // 首个低于阈值的谷
    var tau = -1;
    for (var t = minTau; t <= maxTau; t++) {
      if (yin[t] < threshold) {
        // 取局部最小
        while (t + 1 <= maxTau && yin[t + 1] < yin[t]) {
          t++;
        }
        tau = t;
        break;
      }
    }
    if (tau <= 0) return null;
    // 抛物线插值精化
    final betterTau = _refine(yin, tau);
    final freq = sampleRate / betterTau;
    if (freq < minFreq || freq > maxFreq) return null;
    final clarity = (1 - yin[tau]).clamp(0.0, 1.0);
    return PitchResult(freq, clarity, rms);
  }

  double _refine(List<double> yin, int tau) {
    if (tau <= 0 || tau + 1 >= yin.length) return tau.toDouble();
    final x0 = tau - 1, x1 = tau, x2 = tau + 1;
    final y0 = yin[x0], y1 = yin[x1], y2 = yin[x2];
    final denom = (y0 + y2 - 2 * y1);
    if (denom == 0) return tau.toDouble();
    final shift = 0.5 * (y0 - y2) / denom;
    return x1 + shift.clamp(-1.0, 1.0);
  }
}
