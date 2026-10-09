/// 单次音高检测结果
class PitchResult {
  final double freq; // Hz
  final double clarity; // 0..1，越高越可信
  final double rms; // 音量
  const PitchResult(this.freq, this.clarity, this.rms);
}

/// 音高检测器接口（可替换 YIN/McLeod/FFT 实现）
abstract class PitchDetector {
  PitchResult? detect(List<double> samples, int sampleRate);
}
