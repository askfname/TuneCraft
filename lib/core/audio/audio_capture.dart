import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// 音频采集抽象（UI 层无感知具体声源）
abstract class AudioCapture {
  /// 归一化单声道采样流（-1..1）
  Stream<List<double>> samples({required int sampleRate});
  Future<bool> ensurePermission();
  Future<void> dispose();
}

/// 真机麦克风采集（record pcm16bits stream）
class RecordAudioCapture implements AudioCapture {
  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  StreamController<List<double>>? _ctrl;
  final List<double> _pending = [];
  static const _frameSize = 2048; // YIN 窗长
  static const _hopSize = 1024; // 50% 重叠

  @override
  Future<bool> ensurePermission() => _rec.hasPermission();

  @override
  Stream<List<double>> samples({required int sampleRate}) {
    _ctrl = StreamController<List<double>>.broadcast();
    _start(sampleRate);
    return _ctrl!.stream;
  }

  Future<void> _start(int sampleRate) async {
    final ok = await ensurePermission();
    if (!ok) {
      _ctrl?.addError(StateError('mic-denied'));
      return;
    }
    final stream = await _rec.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    _sub = stream.listen(
      _onBytes,
      onError: _ctrl?.addError,
      onDone: () => _ctrl?.close(),
      cancelOnError: false,
    );
  }

  // PCM16LE -> float，滑窗切帧
  void _onBytes(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _pending.add(bd.getInt16(i, Endian.little) / 32768.0);
    }
    while (_pending.length >= _frameSize) {
      final frame = _pending.sublist(0, _frameSize);
      _pending.removeRange(0, _hopSize);
      if (!(_ctrl?.isClosed ?? true)) _ctrl?.add(frame);
    }
    // 防爆内存
    if (_pending.length > _frameSize * 4) {
      _pending.removeRange(0, _pending.length - _frameSize * 4);
    }
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    try {
      if (await _rec.isRecording()) await _rec.stop();
    } catch (_) {}
    await _rec.dispose();
    await _ctrl?.close();
  }
}
