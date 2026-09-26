import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/audio/piano_audio.dart';
import '../../../core/platform/ime_control.dart';
import '../../../core/util/rational.dart';
import '../../../data/render/sheet_webview.dart';
import '../../../domain/performance/follow_judge.dart';
import '../../../domain/score/convert/split_volume.dart';
import '../../../domain/score/convert/to_event_timeline.dart';
import '../../../domain/score/convert/to_musicxml.dart';
import '../../generation/logic/generation_controller.dart';
import '../../library/library_providers.dart';
import '../logic/playback_engine.dart';
import 'piano_keyboard.dart';

/// 演奏模式页：曲谱（光标同步）+ 虚拟键盘跟弹/聆听。
class PerformancePage extends ConsumerStatefulWidget {
  const PerformancePage({super.key, required this.songId});

  final int songId;

  /// 当前判定器，仅供集成测试断言。
  @visibleForTesting
  static FollowJudge? debugJudge;

  @override
  ConsumerState<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends ConsumerState<PerformancePage>
        // 引擎在播放/暂停/调速时反复重建 ticker，不能用 Single 版
        with
        TickerProviderStateMixin {
  final _sheetController = SheetWebviewController();
  Map<int, double> _stepQuarters = {};

  EventTimeline? _timeline;
  FollowJudge? _judge;
  PlaybackEngine? _engine;
  PianoAudio? _audio;

  FollowMode _mode = FollowMode.followAlong;
  bool _playing = false;
  bool _paused = false;
  bool _showKeyboard = true;
  int _index = -1;
  double _speed = 1.0;

  Set<int> _pressed = {};
  Set<int> _satisfied = {};
  Set<int> _wrongFlash = {};
  Timer? _wrongTimer;

  String? _error;
  bool _loading = true;
  int _cursorStep = -1;
  int _documentBpm = 88;
  Future<String>? _htmlFuture;

  List<ScoreVolume>? _volumes;
  int _volumeIndex = 0;
  final _volumeXml = <int, String>{};

  int _kbLow = 48;
  int _kbHigh = 83;

  @override
  void initState() {
    super.initState();
    // 中文 IME 会吃掉 K 等字母快捷键，演奏期间禁用（本页无文本输入）
    ImeControl.disable();
    _sheetController.events.listen(_onSheetEvent);
    _load();
  }

  Future<void> _load() async {
    try {
      final song = await ref.read(songProvider(widget.songId).future);
      if (song == null || song.scorePath == null) {
        throw Exception('曲谱尚未制作完成');
      }
      final store = await ref.read(scoreStoreProvider.future);
      final doc = await store.load(widget.songId);
      if (doc == null) throw Exception('曲谱数据缺失');
      final timeline = buildTimeline(doc);
      if (timeline.notes.isEmpty) throw Exception('曲谱中没有可演奏的音符');

      final vols = splitIntoVolumes(doc);
      final audio = createPianoAudio();
      await audio.preload();
      if (!mounted) {
        audio.dispose();
        return;
      }
      setState(() {
        _timeline = timeline;
        _documentBpm = doc.meta.bpm;
        _volumes = vols;
        _judge = FollowJudge(notes: timeline.notes, mode: _mode);
        PerformancePage.debugJudge = _judge;
        _audio = audio;
        _fitKeyboard(timeline);
      });
      // 跟弹时不应熄屏（双手在键盘上，无法点亮屏幕）
      WakelockPlus.enable();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fitKeyboard(EventTimeline timeline) {
    final midis = timeline.allMidis;
    if (midis.isEmpty) return;
    var low = midis.reduce((a, b) => a < b ? a : b);
    var high = midis.reduce((a, b) => a > b ? a : b);
    // 窗口 3 个八度（37 键），以音域为中心
    if (high - low > 36) {
      final center = (low + high) / 2;
      low = (center - 18).round();
      high = low + 36;
    }
    low = low.clamp(21, 108 - 36);
    high = (low + 36).clamp(low, 108);
    // 对齐到 C
    while (low % 12 != 0) {
      low--;
    }
    while (high % 12 != 11 && high < 108) {
      high++;
    }
    _kbLow = low;
    _kbHigh = high;
  }

  void _slideKeyboardTo(List<int> midis) {
    if (midis.isEmpty) return;
    final avg = midis.reduce((a, b) => a + b) / midis.length;
    if (avg >= _kbLow + 6 && avg <= _kbHigh - 6) return;
    var low = (avg - 18).round().clamp(21, 72);
    while (low % 12 != 0) {
      low--;
    }
    setState(() {
      _kbLow = low;
      _kbHigh = low + 36;
    });
  }

  // ---- 曲谱 WebView ----

  String _xmlFor(int index) => _volumeXml.putIfAbsent(
    index,
    () => scoreToMusicXml(_volumes![index].document),
  );

  ScoreVolume _volumeFor(Rational q) {
    final vols = _volumes!;
    for (final v in vols) {
      if (q >= v.startQ && q < v.endQ) return v;
    }
    return q < vols.first.startQ ? vols.first : vols.last;
  }

  void _switchToVolume(int index) {
    if (_volumeIndex == index) return;
    setState(() => _volumeIndex = index);
    _sheetController.loadMusicXml(_xmlFor(index));
  }

  /// 当前应高光的音符（聆听=引擎下标；跟弹=判定器当前音）。
  TimelineNote? get _currentNote {
    if (_timeline == null) return null;
    if (_mode == FollowMode.listen) {
      if (_index >= 0 && _index < _timeline!.notes.length) {
        return _timeline!.notes[_index];
      }
      return null;
    }
    return _judge?.current;
  }

  void _onSheetEvent(SheetEvent event) {
    if (event is SheetReady) {
      setState(() => _stepQuarters = event.stepQuarters);
      _resyncCursor();
    } else if (event is SheetError) {
      setState(() => _error = '渲染失败：${event.message}');
    }
  }

  /// 换册重新渲染完成后，把光标对回当前音符（stepQuarters 已更新）。
  void _resyncCursor() {
    final note = _currentNote;
    if (note == null) return;
    final local = note.originalStartQ - _volumes![_volumeIndex].startQ;
    _cursorStep = _stepFor(local.toDouble());
    _sheetController.cursorTo(_cursorStep);
  }

  int _stepFor(double localStartQ) {
    var best = -1;
    var bestQ = double.negativeInfinity;
    _stepQuarters.forEach((step, q) {
      if (q <= localStartQ + 1e-6 && q > bestQ) {
        bestQ = q;
        best = step;
      }
    });
    return best < 0 ? 0 : best;
  }

  void _moveCursor(Rational originalStartQ) {
    final volume = _volumeFor(originalStartQ);
    if (volume.index != _volumeIndex) {
      _switchToVolume(volume.index);
    }
    final local = originalStartQ - volume.startQ;
    final step = _stepFor(local.toDouble());
    if (step == _cursorStep) return;
    _cursorStep = step;
    _sheetController.cursorTo(step);
  }

  // ---- 模式与播放 ----

  void _switchMode(FollowMode mode) {
    if (_playing) _stopAll();
    setState(() {
      _mode = mode;
      _judge = FollowJudge(notes: _timeline!.notes, mode: mode);
      PerformancePage.debugJudge = _judge;
      _index = -1;
      _pressed = {};
      _satisfied = {};
      _cursorStep = -1;
    });
    _switchToVolume(0);
    _sheetController.cursorReset();
  }

  void _startFollow() {
    final judge = _judge!;
    judge.start();
    setState(() {
      _satisfied = {};
    });
    final note = judge.current;
    if (note != null) {
      _moveCursor(note.originalStartQ);
      _slideKeyboardTo(note.midis);
    }
  }

  /// 播放/暂停/继续 三态切换（聆听模式）。
  void _togglePlay() {
    final engine = _engine;
    if (_playing && engine != null && engine.playing) {
      engine.pause();
      setState(() => _paused = true);
      return;
    }
    if (engine != null && _paused) {
      engine.play();
      setState(() => _paused = false);
      return;
    }
    _startListen();
  }

  void _startListen() {
    var engine = _engine;
    if (engine == null) {
      engine = PlaybackEngine(timeline: _timeline!, bpm: _documentBpm)
        ..attach(this);
      engine.onIndexChanged.listen(_onEngineIndex);
      engine.onEnded.listen((_) => _onListenEnded());
      _engine = engine;
    }
    engine.bpm = _documentBpm;
    engine.speed = _speed;
    setState(() {
      _playing = true;
      _paused = false;
    });
    engine.play();
  }

  void _onEngineIndex(int index) {
    final judge = _judge!;
    judge.syncTo(index);
    if (index < 0 || index >= _timeline!.notes.length) {
      setState(() {
        _index = index;
        _satisfied = {};
      });
      return;
    }
    final note = _timeline!.notes[index];
    // 发声
    final audio = _audio;
    if (audio != null) {
      for (final m in note.midis) {
        audio.noteOn(m);
      }
      final durMs = (note.durQ.toDouble() * 60 / _documentBpm * _speed * 1000)
          .round();
      Timer(Duration(milliseconds: durMs.clamp(80, 8000)), () {
        for (final m in note.midis) {
          audio.noteOff(m);
        }
      });
    }
    _moveCursor(note.originalStartQ);
    _slideKeyboardTo(note.midis);
    setState(() {
      _index = index;
      _satisfied = const {};
    });
  }

  void _onListenEnded() {
    if (!mounted) return;
    setState(() {
      _playing = false;
      _paused = false;
    });
    _switchToVolume(0);
    _sheetController.cursorReset();
  }

  void _stopAll() {
    _engine?.stop();
    setState(() {
      _playing = false;
      _paused = false;
      _index = -1;
      _pressed = {};
      _satisfied = {};
      _cursorStep = -1;
    });
    _sheetController.cursorReset();
  }

  void _setSpeed(double s) {
    setState(() => _speed = s);
    _engine?.setSpeed(s);
  }

  // ---- 键盘交互 ----

  void _onKeyDown(int midi) {
    _audio?.noteOn(midi);
    final judge = _judge;
    if (judge == null || judge.phase != JudgePhase.awaiting) {
      setState(() => _pressed = {..._pressed, midi});
      return;
    }
    final fb = judge.pressKey(midi);
    if (fb.correct) {
      setState(() {
        _pressed = {..._pressed, midi};
        _satisfied = {...judge.satisfied};
      });
      if (fb.chordCompleted && _mode == FollowMode.followAlong) {
        _onChordCompleted(judge);
      }
    } else {
      setState(() {
        _pressed = {..._pressed, midi};
        _wrongFlash = {..._wrongFlash, midi};
      });
      _wrongTimer?.cancel();
      _wrongTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _wrongFlash = {});
        }
      });
    }
  }

  void _onChordCompleted(FollowJudge judge) {
    if (judge.isDone) {
      setState(() {
        _satisfied = {};
      });
      _showFinishedDialog();
      return;
    }
    final note = judge.current;
    setState(() => _satisfied = {});
    if (note != null) {
      _moveCursor(note.originalStartQ);
      _slideKeyboardTo(note.midis);
    }
  }

  void _onKeyUp(int midi) {
    _audio?.noteOff(midi);
    setState(() => _pressed = {..._pressed}..remove(midi));
  }

  void _showFinishedDialog() {
    final judge = _judge!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('演奏完成'),
        content: Text(
          '按键正确率 ${(judge.accuracy * 100).toStringAsFixed(0)}%（错误 ${judge.wrongCount} 次）',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startFollow();
            },
            child: const Text('再来一遍'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songProvider(widget.songId));
    final song = songAsync.value;
    final total = _volumes?.length ?? 0;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ResetIntent(),
        SingleActivator(LogicalKeyboardKey.keyK): _ToggleKeyboardIntent(),
        SingleActivator(LogicalKeyboardKey.add): _SpeedUpIntent(),
        SingleActivator(LogicalKeyboardKey.equal): _SpeedUpIntent(),
        SingleActivator(LogicalKeyboardKey.minus): _SpeedDownIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _PrevVolumeIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _NextVolumeIntent(),
      },
      child: Actions(
        actions: {
          _PlayPauseIntent: _PerfAction(_onPlayPauseHotkey),
          _ResetIntent: _PerfAction(_onResetPressed),
          _ToggleKeyboardIntent: _PerfAction(_toggleKeyboard),
          _SpeedUpIntent: _PerfAction(() => _bumpSpeed(0.1)),
          _SpeedDownIntent: _PerfAction(() => _bumpSpeed(-0.1)),
          _PrevVolumeIntent: _PerfAction(() {
            if (_volumeIndex > 0) _switchToVolume(_volumeIndex - 1);
          }),
          _NextVolumeIntent: _PerfAction(() {
            if (_volumeIndex < total - 1) _switchToVolume(_volumeIndex + 1);
          }),
        },
        // 页面初始就有焦点，快捷键不依赖用户先点过某个控件
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text('演奏 · ${song?.title ?? ''}'),
              actions: [
                if (total > 1) ...[
                  IconButton(
                    tooltip: '上一册',
                    icon: const Icon(Icons.navigate_before),
                    onPressed: _volumeIndex > 0
                        ? () => _switchToVolume(_volumeIndex - 1)
                        : null,
                  ),
                  Center(
                    child: Text(
                      '第 ${_volumeIndex + 1}/$total 册',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    tooltip: '下一册',
                    icon: const Icon(Icons.navigate_next),
                    onPressed: _volumeIndex < total - 1
                        ? () => _switchToVolume(_volumeIndex + 1)
                        : null,
                  ),
                ],
                IconButton(
                  tooltip: _showKeyboard ? '隐藏键盘 (K)' : '显示键盘 (K)',
                  icon: Icon(_showKeyboard ? Icons.piano : Icons.piano_off),
                  onPressed: _toggleKeyboard,
                ),
                IconButton(
                  tooltip: '快捷键',
                  icon: const Icon(Icons.keyboard_outlined),
                  onPressed: _showHotkeyHelp,
                ),
                IconButton(
                  tooltip: '重新开始 (Esc)',
                  icon: const Icon(Icons.replay),
                  onPressed: _onResetPressed,
                ),
              ],
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _timeline == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(child: _buildScore()),
                      _buildControls(),
                      if (_showKeyboard) _buildKeyboard(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ---- 快捷键 ----

  void _onPlayPauseHotkey() {
    if (_mode == FollowMode.followAlong) {
      final judge = _judge;
      if (judge != null && judge.phase != JudgePhase.awaiting) _startFollow();
      return;
    }
    _togglePlay();
  }

  void _toggleKeyboard() => setState(() => _showKeyboard = !_showKeyboard);

  void _bumpSpeed(double delta) {
    if (_mode != FollowMode.listen) return;
    _setSpeed((_speed + delta).clamp(0.5, 1.5));
  }

  void _showHotkeyHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('快捷键'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('空格：开始跟弹 / 播放·暂停·继续'),
            Text('Esc：停止并回到开头'),
            Text('K：显示 / 隐藏钢琴键盘'),
            Text('+ / -：速度 ±10%（聆听模式）'),
            Text('← / →：上一册 / 下一册'),
            SizedBox(height: 8),
            Text(
              '若按键无反应，请先点击页面空白处，让焦点离开曲谱区。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _onResetPressed() {
    _stopAll();
    _switchToVolume(0);
    _sheetController.cursorReset();
    setState(() {
      _satisfied = {};
      _pressed = {};
      _cursorStep = -1;
    });
    if (_mode == FollowMode.followAlong) {
      _judge?.reset();
    }
  }

  Widget _buildScore() {
    // 宿主页只加载一次（稳定 Future，避免 setState 重建 WebView）；曲谱按册注入
    _htmlFuture ??= buildSheetHostHtml();
    return FutureBuilder<String>(
      future: _htmlFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            InAppWebView(
              initialData: InAppWebViewInitialData(
                data: snap.data!,
                mimeType: 'text/html',
                encoding: 'utf-8',
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: false,
                supportZoom: false,
                disableContextMenu: true,
              ),
              onWebViewCreated: (w) {
                _sheetController.attach(w);
                w.addJavaScriptHandler(
                  handlerName: 'ejm',
                  callback: (args) {
                    if (args.isNotEmpty && args.first is Map) {
                      _sheetController.handleEvent(
                        SheetEvent.from(args.first as Map),
                      );
                    }
                    return null;
                  },
                );
              },
              onLoadStop: (_, _) async {
                await _sheetController.pageReady;
                await _sheetController.loadMusicXml(_xmlFor(_volumeIndex));
              },
            ),
            if (_mode == FollowMode.followAlong && _judge != null)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _judge!.phase == JudgePhase.awaiting
                        ? '请按亮起的琴键'
                        : '点击「开始跟弹」',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    final judge = _judge;
    final isListen = _mode == FollowMode.listen;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              SegmentedButton<FollowMode>(
                segments: const [
                  ButtonSegment(
                    value: FollowMode.followAlong,
                    label: Text('跟弹'),
                  ),
                  ButtonSegment(value: FollowMode.listen, label: Text('聆听')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _switchMode(s.first),
              ),
              const SizedBox(width: 12),
              if (!isListen)
                FilledButton.icon(
                  onPressed: judge == null || judge.phase == JudgePhase.awaiting
                      ? null
                      : _startFollow,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始跟弹'),
                )
              else ...[
                IconButton.filled(
                  onPressed: _togglePlay,
                  icon: Icon(
                    _playing && !_paused ? Icons.pause : Icons.play_arrow,
                  ),
                  tooltip: _playing && !_paused
                      ? '暂停 (空格)'
                      : _paused
                      ? '继续 (空格)'
                      : '播放 (空格)',
                ),
                IconButton(
                  onPressed: _playing ? _stopAll : null,
                  icon: const Icon(Icons.stop),
                  tooltip: '停止 (Esc)',
                ),
              ],
            ],
          ),
          Row(
            children: [
              const Text('速度', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.5,
                  max: 1.5,
                  divisions: 20,
                  label: '${(_speed * 100).round()}%',
                  // 跟弹模式节奏由人控制，速度仅聆听时生效
                  onChanged: isListen ? _setSpeed : null,
                ),
              ),
              Text('${(_speed * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard() {
    final judge = _judge;
    var hint = <int>{};
    var correct = _satisfied;
    var wrong = _wrongFlash;
    if (_mode == FollowMode.listen &&
        _index >= 0 &&
        _timeline != null &&
        _index < _timeline!.notes.length) {
      hint = {..._timeline!.notes[_index].midis};
    }
    if (_mode == FollowMode.followAlong &&
        judge != null &&
        judge.phase == JudgePhase.awaiting) {
      hint = judge.expected;
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 150,
        child: PianoKeyboard(
          lowMidi: _kbLow,
          highMidi: _kbHigh,
          pressed: _pressed,
          correct: correct,
          wrong: wrong,
          hint: hint,
          onKeyDown: _onKeyDown,
          onKeyUp: _onKeyUp,
        ),
      ),
    );
  }

  @override
  void dispose() {
    ImeControl.restore();
    _wrongTimer?.cancel();
    _engine?.dispose();
    _audio?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}

// ---- 快捷键 intents ----

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _ResetIntent extends Intent {
  const _ResetIntent();
}

class _ToggleKeyboardIntent extends Intent {
  const _ToggleKeyboardIntent();
}

class _SpeedUpIntent extends Intent {
  const _SpeedUpIntent();
}

class _SpeedDownIntent extends Intent {
  const _SpeedDownIntent();
}

class _PrevVolumeIntent extends Intent {
  const _PrevVolumeIntent();
}

class _NextVolumeIntent extends Intent {
  const _NextVolumeIntent();
}

class _PerfAction extends Action<Intent> {
  _PerfAction(this.onInvoke);

  final VoidCallback onInvoke;

  @override
  Object? invoke(Intent intent) {
    onInvoke();
    return null;
  }
}
