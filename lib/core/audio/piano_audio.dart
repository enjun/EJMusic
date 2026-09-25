import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// 钢琴音色抽象：按键出声，便于替换后端（flutter_soloud / 静音）。
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

/// flutter_soloud 实现（全平台，含 Windows 桌面）。
class SoloudPianoAudio implements PianoAudio {
  final _sounds = <int, AudioSource>{}; // sampleMidi -> source

  @override
  Future<void> preload() async {
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
        // 默认声部数偏少：跟弹双手+延音衰减容易打满
        SoLoud.instance.setMaxActiveVoiceCount(32);
      }
    } catch (_) {
      // 无音频设备等环境：静音降级，不阻塞演奏流程
      return;
    }
    for (var m = 24; m <= 108; m += 4) {
      try {
        _sounds[m] =
            await SoLoud.instance.loadAsset('assets/audio/piano/piano_$m.wav');
      } catch (_) {
        // 缺失采样跳过
      }
    }
  }

  @override
  void noteOn(int midi, {double velocity = 1.0}) {
    final sample = sampleMidiFor(midi);
    final sound = _sounds[sample];
    if (sound == null) return;
    // 变调：目标音与采样音相差的半音数 → 频率比。
    // 先 paused 出声部、设变速再恢复，避免变速前的原速起音泄漏。
    final rate = math.pow(2.0, (midi - sample) / 12.0).toDouble();
    try {
      final handle = SoLoud.instance.play(sound, paused: true);
      SoLoud.instance.setRelativePlaySpeed(handle, rate);
      SoLoud.instance.setPause(handle, false);
    } catch (_) {
      // 声部耗尽等播放失败静默
    }
  }

  @override
  void noteOff(int midi) {}

  @override
  void dispose() {
    if (SoLoud.instance.isInitialized) {
      SoLoud.instance.deinit();
    }
    _sounds.clear();
  }
}

/// 兜底占位实现：不出声，接口可用（Web 等）。
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
  return SoloudPianoAudio();
}
