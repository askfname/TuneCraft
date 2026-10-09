import 'package:flutter_test/flutter_test.dart';
import 'package:tunecraft/core/tuning/tuning_math.dart';
import 'package:tunecraft/domain/instruments/guitar.dart';

void main() {
  test('标准频率换算', () {
    expect(TuningMath.midiToFreq(69), closeTo(440, 0.01));
    expect(TuningMath.midiToFreq(40), closeTo(82.41, 0.05));
  });

  test('音分偏差：偏高为正、偏低为负', () {
    expect(TuningMath.centsBetween(440, 440), closeTo(0, 1e-6));
    expect(TuningMath.centsBetween(466.16, 440), closeTo(100, 0.5));
    expect(TuningMath.centsBetween(82.41 * 1.01, 82.41), greaterThan(0));
  });

  test('吉他 6 弦标准音', () {
    final g = GuitarStandardInstrument();
    expect(g.strings.length, 6);
    expect(g.strings.first.freq, closeTo(82.41, 0.01));
    expect(g.strings.last.freq, closeTo(329.63, 0.01));
    expect(g.supportedLayouts.length, 2); // 3+3 与单侧6弦
  });

  test('分级：±5准、±15接近、其余偏离', () {
    expect(TuningMath.grade(3), TuneGrade.inTune);
    expect(TuningMath.grade(10), TuneGrade.close);
    expect(TuningMath.grade(30), TuneGrade.off);
  });
}
