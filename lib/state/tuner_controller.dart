import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_capture.dart';
import '../core/pitch/pitch_detector.dart';
import '../core/pitch/yin_pitch_detector.dart';
import '../core/tuning/tuning_math.dart';
import '../domain/headstock_layout.dart';
import '../domain/instruments/guitar.dart';
import '../domain/instruments/instrument.dart';

/// 选弦模式：自动识别 / 手动锁定
enum TunerMode { auto, manual }

/// 调音快照（UI 只读此对象）
class TunerState {
  final Instrument instrument;
  final HeadstockLayout layout;
  final TunerMode mode;
  final TuningString target; // 当前判定对象（自动=最近弦，手动=锁定弦）
  final int? lockedIndex; // 手动锁定的弦号
  final double? freq; // 实测 Hz
  final double? cents; // 相对 target 的偏差（+偏高）
  final double smoothCents; // 指针用平滑值
  final double clarity;
  final TuneGrade grade;
  final bool listening;
  final bool permissionDenied;
  final String? error;

  const TunerState({
    required this.instrument,
    required this.layout,
    required this.mode,
    required this.target,
    this.lockedIndex,
    this.freq,
    this.cents,
    this.smoothCents = 0,
    this.clarity = 0,
    this.grade = TuneGrade.off,
    this.listening = false,
    this.permissionDenied = false,
    this.error,
  });

  bool get hasSignal => freq != null && cents != null;
  bool get inTune => hasSignal && grade == TuneGrade.inTune;

  TunerState copyWith({
    Instrument? instrument,
    HeadstockLayout? layout,
    TunerMode? mode,
    TuningString? target,
    int? Function()? lockedIndex,
    double? Function()? freq,
    double? Function()? cents,
    double? smoothCents,
    double? clarity,
    TuneGrade? grade,
    bool? listening,
    bool? permissionDenied,
    String? Function()? error,
  }) =>
      TunerState(
        instrument: instrument ?? this.instrument,
        layout: layout ?? this.layout,
        mode: mode ?? this.mode,
        target: target ?? this.target,
        lockedIndex: lockedIndex != null ? lockedIndex() : this.lockedIndex,
        freq: freq != null ? freq() : this.freq,
        cents: cents != null ? cents() : this.cents,
        smoothCents: smoothCents ?? this.smoothCents,
        clarity: clarity ?? this.clarity,
        grade: grade ?? this.grade,
        listening: listening ?? this.listening,
        permissionDenied: permissionDenied ?? this.permissionDenied,
        error: error != null ? error() : this.error,
      );
}

/// 调音控制器：采集 -> 检音 -> 匹配弦 -> 平滑输出
class TunerController extends Notifier<TunerState> {
  static const sampleRate = 44100;
  PitchDetector _detector = YinPitchDetector();
  AudioCapture? _capture;
  StreamSubscription<List<double>>? _sub;

  // 自动模式防抖：避免两弦中间值导致 target 乱跳
  DateTime _lastSwitch = DateTime.fromMillisecondsSinceEpoch(0);
  final List<double> _freqWindow = []; // 中值滤波窗

  @override
  TunerState build() {
    final guitar = GuitarStandardInstrument();
    ref.onDispose(() {
      _sub?.cancel(); // 页面销毁时停拾音
    });
    return TunerState(
      instrument: guitar,
      layout: guitar.defaultLayout,
      mode: TunerMode.auto,
      target: guitar.strings[2], // 默认 D3，启动后自动纠正
    );
  }

  // --- 对外操作（进屏自动 start，无手动开关）---

  Future<void> start() async {
    await stop();
    state = state.copyWith(
      listening: true,
      permissionDenied: false,
      error: () => null,
    );
    _detector = YinPitchDetector(
      minFreq: state.instrument.minFreq - 10,
      maxFreq: state.instrument.maxFreq + 700,
    );
    try {
      final cap = RecordAudioCapture();
      _capture = cap;
      final ok = await cap.ensurePermission();
      if (!ok) {
        state = state.copyWith(
            listening: false, permissionDenied: true, error: () => 'mic-denied');
        return;
      }
      _sub = cap.samples(sampleRate: sampleRate).listen(
            _onFrame,
            onError: (e) => state = state.copyWith(
                listening: false, error: () => e.toString()),
          );
    } catch (e) {
      state = state.copyWith(listening: false, error: () => e.toString());
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _capture?.dispose();
    _capture = null;
    _freqWindow.clear();
    if (state.listening) state = state.copyWith(listening: false);
  }

  void setMode(TunerMode m, {int? lockIndex}) {
    if (m == TunerMode.manual) {
      final idx = lockIndex ?? state.target.index;
      final t = _stringOf(idx);
      state = state.copyWith(
        mode: m,
        lockedIndex: () => idx,
        target: t,
      );
    } else {
      state = state.copyWith(mode: m, lockedIndex: () => null);
    }
  }

  void lockString(int index) {
    final t = _stringOf(index);
    state = state.copyWith(
      mode: TunerMode.manual,
      lockedIndex: () => index,
      target: t,
    );
  }

  void unlockToAuto() => setMode(TunerMode.auto);

  void setLayout(HeadstockLayout l) => state = state.copyWith(layout: l);

  void setInstrument(Instrument ins) {
    // 预留：切换贝司/尤克里里入口，自动重置目标与布局
    state = state.copyWith(
      instrument: ins,
      layout: ins.defaultLayout,
      target: ins.strings[ins.strings.length ~/ 2],
      lockedIndex: () => null,
      mode: TunerMode.auto,
      freq: () => null,
      cents: () => null,
    );
    _freqWindow.clear();
  }

  // --- 内部管线 ---

  TuningString _stringOf(int index) =>
      state.instrument.strings.firstWhere((e) => e.index == index);

  void _onFrame(List<double> frame) {
    final r = _detector.detect(frame, sampleRate);
    if (r == null || r.clarity < 0.35) {
      // 弱信号：保留 target，只清读数（指针回中不停跳）
      _freqWindow.clear();
      state = state.copyWith(freq: () => null, cents: () => null, clarity: 0);
      return;
    }
    // 中值滤波抑噪
    _freqWindow.add(r.freq);
    if (_freqWindow.length > 5) _freqWindow.removeAt(0);
    final sorted = [..._freqWindow]..sort();
    final freq = sorted[sorted.length ~/ 2];

    final TuningString target;
    if (state.mode == TunerMode.manual) {
      target = _stringOf(state.lockedIndex ?? state.target.index);
    } else {
      target = _nearest(freq);
      // 300ms 内不反复切换
      if (target.index != state.target.index &&
          DateTime.now().difference(_lastSwitch).inMilliseconds < 300) {
        return;
      }
      if (target.index != state.target.index) _lastSwitch = DateTime.now();
    }

    final cents = TuningMath.centsBetween(freq, target.freq);
    // 指数平滑指针（0.35 跟手、0.65 稳）
    final clamped = cents.clamp(-60, 60).toDouble();
    final smooth = state.hasSignal
        ? state.smoothCents * 0.65 + clamped * 0.35
        : clamped;
    state = state.copyWith(
      target: target,
      freq: () => freq,
      cents: () => cents,
      smoothCents: smooth,
      clarity: r.clarity,
      grade: TuningMath.grade(cents.abs()),
    );
  }

  TuningString _nearest(double freq) {
    TuningString best = state.instrument.strings.first;
    var bestAbs = double.infinity;
    for (final s in state.instrument.strings) {
      final c = TuningMath.centsBetween(freq, s.freq).abs();
      if (c < bestAbs) {
        bestAbs = c;
        best = s;
      }
    }
    return best;
  }
}

final tunerProvider = NotifierProvider<TunerController, TunerState>(
  TunerController.new,
);
