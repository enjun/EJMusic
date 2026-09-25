import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/piano_audio.dart';
import '../../../data/render/sheet_webview.dart';
import '../../../domain/performance/follow_judge.dart';
import '../../../domain/score/convert/to_event_timeline.dart';
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
    with SingleTickerProviderStateMixin {
  final _sheetController = SheetWebviewController();
  Map<int, double> _stepQuarters = {};

  EventTimeline? _timeline;
  FollowJudge? _judge;
  PlaybackEngine? _engine;
  PianoAudio? _audio;

  FollowMode _mode = FollowMode.followAlong;
  bool _playing = false;
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
  Future<List<String>>? _scoreHost;

  int _kbLow = 48;
  int _kbHigh = 83;

  @override
  void initState() {
    super.initState();
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

      final audio = createPianoAudio();
      await audio.preload();
      if (!mounted) {
        audio.dispose();
        return;
      }
      setState(() {
        _timeline = timeline;
        _documentBpm = doc.meta.bpm;
        _judge = FollowJudge(notes: timeline.notes, mode: _mode);
        PerformancePage.debugJudge = _judge;
        _audio = audio;
        _fitKeyboard(timeline);
      });
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
    var low = (avg - 18).round().clamp(21, 72) ;
    while (low % 12 != 0) {
      low--;
    }
    setState(() {
      _kbLow = low;
      _kbHigh = low + 36;
    });
  }

  // ---- 曲谱 WebView ----

  void _onSheetEvent(SheetEvent event) {
    if (event is SheetReady) {
      setState(() => _stepQuarters = event.stepQuarters);
    } else if (event is SheetError) {
      setState(() => _error = '渲染失败：${event.message}');
    }
  }

  int _stepFor(double originalStartQ) {
    var best = -1;
    var bestQ = double.negativeInfinity;
    _stepQuarters.forEach((step, q) {
      if (q <= originalStartQ + 1e-6 && q > bestQ) {
        bestQ = q;
        best = step;
      }
    });
    return best < 0 ? 0 : best;
  }

  void _moveCursor(double originalStartQ) {
    final step = _stepFor(originalStartQ);
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
      _moveCursor(note.originalStartQ.toDouble());
      _slideKeyboardTo(note.midis);
    }
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
    setState(() => _playing = true);
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
      final durMs = (note.durQ.toDouble() * 60 / _documentBpm * _speed * 1000).round();
      Timer(Duration(milliseconds: durMs.clamp(80, 8000)), () {
        for (final m in note.midis) {
          audio.noteOff(m);
        }
      });
    }
    _moveCursor(note.originalStartQ.toDouble());
    _slideKeyboardTo(note.midis);
    setState(() {
      _index = index;
      _satisfied = const {};
    });
  }

  void _onListenEnded() {
    if (!mounted) return;
    setState(() => _playing = false);
    _sheetController.cursorReset();
  }

  void _stopAll() {
    _engine?.stop();
    setState(() {
      _playing = false;
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
      _moveCursor(note.originalStartQ.toDouble());
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
            '按键正确率 ${(judge.accuracy * 100).toStringAsFixed(0)}%（错误 ${judge.wrongCount} 次）'),
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
    final xmlPath = song?.musicxmlCachePath;

    return Scaffold(
      appBar: AppBar(
        title: Text('演奏 · ${song?.title ?? ''}'),
        actions: [
          IconButton(
            tooltip: '重新开始',
            icon: const Icon(Icons.replay),
            onPressed: _onResetPressed,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _timeline == null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : Column(
                  children: [
                    Expanded(child: _buildScore(xmlPath)),
                    _buildControls(),
                    _buildKeyboard(),
                  ],
                ),
    );
  }

  void _onResetPressed() {
    _stopAll();
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

  Widget _buildScore(String? xmlPath) {
    if (xmlPath == null || !File(xmlPath).existsSync()) {
      return const Center(child: Text('曲谱文件缺失'));
    }
    // 缓存宿主页+曲谱加载 Future，避免 setState 重建时反复读 2MB JS
    _scoreHost ??= Future.wait([buildSheetHostHtml(), File(xmlPath).readAsString()]);
    return FutureBuilder<List<String>>(
      future: _scoreHost,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            InAppWebView(
              initialData: InAppWebViewInitialData(
                data: snap.data![0],
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
                w.addJavaScriptHandler(handlerName: 'ejm', callback: (args) {
                  if (args.isNotEmpty && args.first is Map) {
                    _sheetController
                        .handleEvent(SheetEvent.from(args.first as Map));
                  }
                  return null;
                });
              },
              onLoadStop: (_, _) async {
                await _sheetController.pageReady;
                await _sheetController.loadMusicXml(snap.data![1]);
              },
            ),
            if (_mode == FollowMode.followAlong && _judge != null)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              SegmentedButton<FollowMode>(
                segments: const [
                  ButtonSegment(value: FollowMode.followAlong, label: Text('跟弹')),
                  ButtonSegment(value: FollowMode.listen, label: Text('聆听')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _switchMode(s.first),
              ),
              const SizedBox(width: 12),
              if (_mode == FollowMode.followAlong)
                FilledButton.icon(
                  onPressed: judge == null || judge.phase == JudgePhase.awaiting
                      ? null
                      : _startFollow,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始跟弹'),
                )
              else ...[
                IconButton.filled(
                  onPressed: _playing ? _stopAll : _startListen,
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  tooltip: _playing ? '停止' : '播放',
                ),
                Expanded(
                  child: Slider(
                    value: _speed,
                    min: 0.5,
                    max: 1.5,
                    divisions: 20,
                    label: '${(_speed * 100).round()}%',
                    onChanged: _setSpeed,
                  ),
                ),
                Text('${(_speed * 100).round()}%'),
              ],
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
    _wrongTimer?.cancel();
    _engine?.dispose();
    _audio?.dispose();
    super.dispose();
  }
}
