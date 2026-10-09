import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tunecraft/core/pitch/yin_pitch_detector.dart';

// 合成正弦（含谐波 + 微噪），验证 YIN 精度
List<double> synth(double freq, int sr, {int n = 2048}) {
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    out[i] = 0.6 * math.sin(2 * math.pi * freq * t) +
        0.25 * math.sin(2 * math.pi * freq * 2 * t) +
        0.05 * math.sin(2 * math.pi * freq * 3 * t);
  }
  return out;
}

void main() {
  final yin = YinPitchDetector();

  test('A4 440Hz 误差 <2Hz', () {
    final r = yin.detect(synth(440, 44100), 44100);
    expect(r, isNotNull);
    expect(r!.freq, closeTo(440, 2.0));
    expect(r.clarity, greaterThan(0.5));
  });

  test('吉他低 E 82.41Hz 误差 <2Hz', () {
    final r = yin.detect(synth(82.41, 44100), 44100);
    expect(r, isNotNull);
    expect(r!.freq, closeTo(82.41, 2.0));
  });

  test('吉他高 E 329.63Hz 误差 <3Hz', () {
    final r = yin.detect(synth(329.63, 44100), 44100);
    expect(r, isNotNull);
    expect(r!.freq, closeTo(329.63, 3.0));
  });

  test('静音返回 null（指针不乱跳）', () {
    final r = yin.detect(List.filled(2048, 0.0), 44100);
    expect(r, isNull);
  });
}
