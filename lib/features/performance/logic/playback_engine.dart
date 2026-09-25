import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../../../domain/score/convert/to_event_timeline.dart';

/// 聆听模式播放引擎：Dart Ticker 为时间权威，仅在音符切换时发出事件。
/// 光标/键盘高亮由 UI 监听 [onIndexChanged] 驱动；渲染桥只收 step 变更。
class PlaybackEngine {
  PlaybackEngine({required this.timeline, required this.bpm});

  final EventTimeline timeline;
  int bpm;

  /// 调速倍率（0.5 ~ 1.5）。
  double speed = 1.0;

  bool get playing => _ticker != null;
  int get index => _index;

  /// 当前播放位置（毫秒）。
  double get currentMs => _currentMs;

  double get totalMs => timeline.totalQ.toDouble() * 60000 / (bpm * speed);

  /// 音符下标切换事件（-1 表示未开始/已复位）。
  Stream<int> get onIndexChanged => _indexStream.stream;

  /// 播放到结尾。
  Stream<void> get onEnded => _endedStream.stream;

  Ticker? _ticker;
  TickerProvider? _vsync;
  double _currentMs = 0;
  double _baseMs = 0; // 本次 start 时的位置
  Duration? _firstTick;
  int _index = -1;

  final _indexStream = StreamController<int>.broadcast();
  final _endedStream = StreamController<void>.broadcast();

  /// 播放前调用（引擎所在 State 的 vsync）。
  void attach(TickerProvider vsync) => _vsync = vsync;

  void play() {
    if (playing) return;
    if (_currentMs >= totalMs) _currentMs = 0;
    _baseMs = _currentMs;
    _firstTick = null;
    _ticker = _vsync?.createTicker(_onTick);
    _ticker?.start();
  }

  void _onTick(Duration elapsed) {
    _firstTick ??= elapsed;
    _currentMs = _baseMs + (elapsed - _firstTick!).inMilliseconds;
    _updateIndex();
    if (_currentMs >= totalMs) {
      pause();
      _index = timeline.notes.length;
      _indexStream.add(_index);
      _endedStream.add(null);
    }
  }

  void pause() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void stop() {
    pause();
    _currentMs = 0;
    _setIndex(-1);
  }

  /// 跳转到展开位置（四分音符单位）。
  void seekQ(double quarter) {
    _currentMs = quarter * 60000 / (bpm * speed);
    if (playing) {
      pause();
      play();
    }
    _updateIndex();
  }

  void setSpeed(double s) {
    // 保持位置不变换算时间基准
    final q = _currentMs * (bpm * speed) / 60000;
    speed = s;
    _currentMs = q * 60000 / (bpm * speed);
    if (playing) {
      pause();
      play();
    }
    _updateIndex();
  }

  void dispose() {
    pause();
    _indexStream.close();
    _endedStream.close();
  }

  void _setIndex(int i) {
    if (i == _index) return;
    _index = i;
    if (!_indexStream.isClosed) _indexStream.add(i);
  }

  void _updateIndex() {
    final factor = 60000 / (bpm * speed);
    final notes = timeline.notes;
    var lo = 0;
    var hi = notes.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (notes[mid].startQ.toDouble() * factor <= _currentMs + 1e-6) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    _setIndex(ans);
  }
}
