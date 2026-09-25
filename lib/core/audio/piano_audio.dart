import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:soundpool/soundpool.dart';

/// 钢琴音色抽象：按键出声，便于替换后端（soundpool / flutter_soloud / 静音）。
abstract class PianoAudio {
  /// 预加载采样（App 启动或进入演奏页时）。
  Future<void> preload();

  /// 按下琴键发声。
  void noteOn(int midi, {double velocity = 1.0});

  /// 松开（钢琴采样自然衰减，可空实现）。
  void noteOff(int midi);

  void dispose();
}

/// 按半音网格取最近采样（步长 4，C1=24 到 C8=108）。
int sampleMidiFor(int midi) {
  const low = 24, step = 4, count = 22;
  final idx = ((midi - low) / step).round().clamp(0, count - 1);
  return low + idx * step;
}

/// soundpool 实现（Android / iOS / macOS）。
class SoundpoolPianoAudio implements PianoAudio {
  SoundpoolPianoAudio() {
    _pool = Soundpool.fromOptions(
      options: const SoundpoolOptions(maxStreams: 8, streamType: StreamType.music),
    );
  }

  late final Soundpool _pool;
  final _soundIds = <int, int>{}; // sampleMidi -> soundId

  @override
  Future<void> preload() async {
    for (var m = 24; m <= 108; m += 4) {
      try {
        final data = await rootBundle.load('assets/audio/piano/piano_$m.wav');
        _soundIds[m] = await _pool.load(data);
      } catch (_) {
        // 缺失采样跳过
      }
    }
  }

  @override
  void noteOn(int midi, {double velocity = 1.0}) {
    final sample = sampleMidiFor(midi);
    final id = _soundIds[sample];
    if (id == null) return;
    // 变调：目标音与采样音相差的半音数 → 频率比
    final rate = math.pow(2.0, (midi - sample) / 12.0).toDouble();
    _pool.play(id, rate: rate);
  }

  @override
  void noteOff(int midi) {}

  @override
  void dispose() {
    _pool.dispose();
  }
}

/// 桌面端占位实现（Windows/Linux 无 soundpool）：不出声，接口可用。
class SilentPianoAudio implements PianoAudio {
  @override
  Future<void> preload() async {}

  @override
  void noteOn(int midi, {double velocity = 1.0}) {}

  @override
  void noteOff(int midi) {}

  @override
  void dispose() {}
}

PianoAudio createPianoAudio() {
  if (kIsWeb) return SilentPianoAudio();
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return SoundpoolPianoAudio();
  }
  return SilentPianoAudio();
}
