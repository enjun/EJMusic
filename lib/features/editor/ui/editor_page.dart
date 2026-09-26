import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/platform/ime_control.dart';
import '../../../core/util/rational.dart';
import '../../../data/render/sheet_webview.dart';
import '../../../domain/score/convert/to_musicxml.dart';
import '../../../domain/score/score_document.dart';
import '../../generation/logic/generation_controller.dart';
import '../../library/library_providers.dart';
import '../logic/score_editor.dart';

/// 曲谱手动编辑页：上半渲染五线谱，点击音符/休止符直接选中编辑，
/// 保存时校验+修复并重生成 MusicXML 缓存。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.songId});

  final int songId;

  /// 集成测试观察点：最近一次点击选中的 cursor 步号。
  static int? debugSelectedStep;

  /// 集成测试观察点：最近一次 ready 的总步数 / 成功映射到事件的步数。
  static int? debugTotalSteps;
  static int? debugMappedSteps;

  /// 集成测试观察点：编辑页的渲染桥（用于在宿主页执行 JS）。
  static SheetWebviewController? debugSheet;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  ScoreDocument? _doc;
  String? _error;
  bool _saving = false;
  bool _dirty = false;

  final SheetWebviewController _sheet = SheetWebviewController();
  Future<String>? _htmlFuture;
  double _zoom = 1.0;

  /// cursor 步号 → 小节下标（ready 后由渲染桥给出，选中高亮用）。
  Map<int, int> _stepMeasure = {};
  ScoreEvent? _selected;
  Timer? _renderDebounce;

  // 键盘钢琴输入状态：当前八度（中央 C 所在为 4）、时值、附点数。
  int _inputOctave = 4;
  Rational _inputDur = const Rational(1, 1);
  int _inputDots = 0;

  /// 键盘 1-6 对应的时值（全音符→三十二分音符）。
  static const List<(String, Rational)> _durPresets = [
    ('全音符', Rational(4, 1)),
    ('二分音符', Rational(2, 1)),
    ('四分音符', Rational(1, 1)),
    ('八分音符', Rational(1, 2)),
    ('十六分音符', Rational(1, 4)),
    ('三十二分音符', Rational(1, 8)),
  ];

  /// 键盘→琴键映射：(音名, 变化数, 相对当前八度的偏移)。
  /// A S D F G H J K L = C D E F G A B C₊₁ D₊₁；
  /// W E T Y U = C♯ D♯ F♯ G♯ A♯；O P = 高八度 C♯ D♯。
  static final Map<LogicalKeyboardKey, (String, int, int)> _pianoKeys = {
    LogicalKeyboardKey.keyA: ('C', 0, 0),
    LogicalKeyboardKey.keyS: ('D', 0, 0),
    LogicalKeyboardKey.keyD: ('E', 0, 0),
    LogicalKeyboardKey.keyF: ('F', 0, 0),
    LogicalKeyboardKey.keyG: ('G', 0, 0),
    LogicalKeyboardKey.keyH: ('A', 0, 0),
    LogicalKeyboardKey.keyJ: ('B', 0, 0),
    LogicalKeyboardKey.keyK: ('C', 0, 1),
    LogicalKeyboardKey.keyL: ('D', 0, 1),
    LogicalKeyboardKey.keyW: ('C', 1, 0),
    LogicalKeyboardKey.keyE: ('D', 1, 0),
    LogicalKeyboardKey.keyT: ('F', 1, 0),
    LogicalKeyboardKey.keyY: ('G', 1, 0),
    LogicalKeyboardKey.keyU: ('A', 1, 0),
    LogicalKeyboardKey.keyO: ('C', 1, 1),
    LogicalKeyboardKey.keyP: ('D', 1, 1),
  };

  @override
  void initState() {
    super.initState();
    EditorPage.debugSheet = _sheet;
    // 中文 IME 会吃掉字母键（VK_PROCESSKEY），编辑期间禁用；文本框获焦时恢复
    ImeControl.disable();
    FocusManager.instance.addListener(_focusChanged);
    _reload();
  }

  void _focusChanged() {
    final f = FocusManager.instance.primaryFocus;
    if (f?.context?.widget is EditableText) {
      ImeControl.restore();
    } else {
      ImeControl.disable();
    }
  }

  @override
  void dispose() {
    EditorPage.debugSheet = null;
    FocusManager.instance.removeListener(_focusChanged);
    ImeControl.restore();
    _renderDebounce?.cancel();
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final store = await ref.read(scoreStoreProvider.future);
      final doc = await store.load(widget.songId);
      if (doc == null) throw Exception('曲谱数据缺失，请先制作曲谱');
      setState(() {
        _doc = doc;
        _dirty = false;
        _error = null;
        _selected = null;
        _stepMeasure = {};
      });
      unawaited(_renderDoc());
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _renderDoc() async {
    final doc = _doc;
    if (doc == null) return;
    final sw = Stopwatch()..start();
    try {
      // load 本身按当前缩放渲染，不再先 setZoom（避免一次多余的重渲染，
      // 打开页面时连续两次全量渲染会吞掉最初的点击）
      await _sheet.loadMusicXml(scoreToMusicXml(doc), zoom: _zoom);
      debugPrint('EJM editor: 渲染完成 ${sw.elapsedMilliseconds}ms');
      _restoreHighlight();
    } catch (e) {
      debugPrint('EJM editor: 渲染异常 $e');
    }
  }

  /// 重渲染会重建 DOM，选中高亮（JS 侧填充色）丢失，渲染后重发。
  void _restoreHighlight() {
    final loc = _selected == null ? null : _locate(_selected!);
    if (loc != null) {
      unawaited(_sheet.highlight(loc.$3, loc.$1.staff - 1, loc.$2));
    }
  }

  void _scheduleRender() {
    _renderDebounce?.cancel();
    _renderDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_renderDoc());
    });
  }

  /// 任何改动后：标脏 + 防抖重渲染谱面。
  void _afterChange() {
    if (!_dirty) setState(() => _dirty = true);
    _scheduleRender();
  }

  void _onReady(SheetReady ready) {
    setState(() => _stepMeasure = ready.stepMeasures);
    EditorPage.debugTotalSteps = ready.totalSteps;
    EditorPage.debugMappedSteps = ready.stepMeasures.length;
  }

  /// 点击谱面音符：事件身份直接来自 OSMD 图形模型，越界即忽略。
  void _onNoteClicked(SheetNoteClicked click) {
    final doc = _doc;
    if (doc == null) return;
    final measures = doc.parts.first.measures;
    if (click.measure < 0 || click.measure >= measures.length) {
      debugPrint('EJM editor: 点击小节越界 m=${click.measure}');
      return;
    }
    final measure = measures[click.measure];
    ScoreVoice? voice;
    for (final v in measure.voices) {
      if (v.staff == click.staff + 1) {
        voice = v;
        break;
      }
    }
    if (voice == null) {
      debugPrint('EJM editor: 点击无对应声部 m=${click.measure} s=${click.staff}');
      return;
    }
    if (click.eventIndex >= voice.events.length) {
      debugPrint(
        'EJM editor: 点击事件越界 m=${click.measure} s=${click.staff} '
        'k=${click.eventIndex} 共${voice.events.length}个事件',
      );
      return;
    }
    final event = voice.events[click.eventIndex];
    debugPrint(
      'EJM editor: 选中 m=${click.measure} s=${click.staff} '
      'k=${click.eventIndex} → ${eventLabel(event)}',
    );
    setState(() => _selected = event);
    // 高亮：定位到该小节的第一个 cursor 步
    int? step;
    for (final s in _stepMeasure.keys.toList()..sort()) {
      if (_stepMeasure[s] == click.measure) {
        step = s;
        break;
      }
    }
    if (step != null) unawaited(_sheet.selectStep(step));
  }

  void _onSheetEvent(SheetEvent event) {
    if (!mounted) return;
    switch (event) {
      case SheetReady():
        _onReady(event);
      case SheetNoteClicked():
        debugPrint(
          'EJM editor: noteClicked m=${event.measure} s=${event.staff} '
          'k=${event.eventIndex}',
        );
        EditorPage.debugSelectedStep = event.eventIndex;
        _onNoteClicked(event);
      case SheetError(:final message):
        debugPrint('EJM editor: SheetError $message');
        // 已有文档在编辑时不要吞掉整页，只提示
        if (_doc != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('渲染失败：$message'),
                duration: const Duration(seconds: 3),
              ),
            );
        } else {
          setState(() => _error = '渲染失败：$message');
        }
      default:
        break;
    }
  }

  Future<void> _save() async {
    final doc = _doc;
    if (doc == null || _saving) return;
    setState(() => _saving = true);
    try {
      // 结构性错误（拍数不符等）由校验器在保存流程中自动修复
      final result = await saveEditedScore(
        store: await ref.read(scoreStoreProvider.future),
        songId: widget.songId,
        doc: doc,
      );
      await ref
          .read(appDatabaseProvider)
          .songsDao
          .updateScoreMeta(
            songId: widget.songId,
            title: doc.meta.title,
            composer: doc.meta.composer,
            keyFifths: doc.meta.keyFifths,
            timeBeats: doc.meta.timeBeats,
            timeBeatType: doc.meta.timeBeatType,
            bpm: doc.meta.bpm,
          );
      ref.invalidate(songsStreamProvider);
      ref.invalidate(songProvider(widget.songId));
      if (!mounted) return;
      final msg = result.errors.isNotEmpty
          ? '已保存，但有问题未修复：${result.errors.take(2).join('；')}'
          : result.warnings.isNotEmpty
          ? '已保存（${result.warnings.length} 处自动修复）'
          : '已保存';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- 谱面选中操作 ----

  /// 在文档中定位事件 → (声部, 声部内下标, 小节下标)。
  (ScoreVoice, int, int)? _locate(ScoreEvent e) {
    final doc = _doc;
    if (doc == null) return null;
    final measures = doc.parts.first.measures;
    for (var mi = 0; mi < measures.length; mi++) {
      for (final v in measures[mi].voices) {
        final i = v.events.indexOf(e);
        if (i >= 0) return (v, i, mi);
      }
    }
    return null;
  }

  void _insertEvent(bool note) {
    _insertEventAt(
      ScoreEvent(
        type: note ? 'note' : 'rest',
        dur: const Rational(1, 1),
        pitches: note ? [ScorePitch(step: 'C', alter: 0, octave: 4)] : [],
      ),
    );
  }

  /// 按当前键盘输入状态（八度/时值/附点）插入一个音符，
  /// 插入位置为选中事件之后，新事件成为选中项（连续输入即顺序追加）。
  void _insertPianoNote((String, int, int) spec) {
    final octave = _inputOctave + spec.$3;
    if (octave < 0 || octave > 8) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('超出音域（八度 0-8），请用 Z/X 调整八度'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    final dots = _inputDots;
    final e = ScoreEvent(
      type: 'note',
      // 附点时值 = 基础时值 × (2 - 2^-dots)：1 附点 ×3/2，2 附点 ×7/4
      dur: (_inputDur * Rational(2 * (1 << dots) - 1, 1 << dots)).reduced(),
      dots: dots,
      pitches: [ScorePitch(step: spec.$1, alter: spec.$2, octave: octave)],
    );
    // 连续输入时不逐键弹提示，滚动定位足以确认
    _insertEventAt(e, feedback: false);
  }

  /// 在选中事件之后插入 [e]（无选中则追加到末尾），并滚动定位让用户看见。
  void _insertEventAt(ScoreEvent e, {bool feedback = true}) {
    final doc = _doc;
    if (doc == null) return;
    final sel = _selected;
    final loc = sel == null ? null : _locate(sel);
    final int measureIndex;
    if (loc != null) {
      loc.$1.events.insert(loc.$2 + 1, e);
      measureIndex = loc.$3;
      debugPrint(
        'EJM editor: 插入 ${eventLabel(e)} 于 m=$measureIndex '
        'staff=${loc.$1.staff} index=${loc.$2 + 1}',
      );
    } else {
      final measures = doc.parts.first.measures;
      measures.last.voices.last.events.add(e);
      measureIndex = measures.length - 1;
      debugPrint('EJM editor: 无选中，${eventLabel(e)} 追加到末尾 m=$measureIndex');
    }
    setState(() => _selected = e);
    _afterChange();
    // 必须让用户看见插入结果：滚动到该小节（feedback 时再提示位置）
    _revealMeasure(
      measureIndex,
      feedback ? '已在第 ${measureIndex + 1} 小节插入${eventLabel(e)}' : null,
    );
  }

  /// 滚动谱面到指定小节（0 基）；[message] 非空时同时提示。
  void _revealMeasure(int measureIndex, String? message) {
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
    }
    int? step;
    for (final s in _stepMeasure.keys.toList()..sort()) {
      if (_stepMeasure[s] == measureIndex) {
        step = s;
        break;
      }
    }
    if (step != null) unawaited(_sheet.cursorTo(step));
  }

  /// 全谱事件的一维顺序表（小节序 → 谱表序 → 声部内序），
  /// 左右方向键按此顺序移动选中。元素 = (声部, 声部内下标, 小节下标)。
  List<(ScoreVoice, int, int)> _flatEvents() {
    final doc = _doc;
    if (doc == null) return [];
    final out = <(ScoreVoice, int, int)>[];
    final measures = doc.parts.first.measures;
    for (var mi = 0; mi < measures.length; mi++) {
      final voices = [...measures[mi].voices]
        ..sort((a, b) => a.staff.compareTo(b.staff));
      for (final v in voices) {
        for (var i = 0; i < v.events.length; i++) {
          out.add((v, i, mi));
        }
      }
    }
    return out;
  }

  /// 左右方向键移动选中（delta = -1/1）；无选中时选第一个/最后一个。
  void _selectNeighbor(int delta) {
    final list = _flatEvents();
    if (list.isEmpty) return;
    var idx = -1;
    final loc = _selected == null ? null : _locate(_selected!);
    if (loc != null) {
      for (var i = 0; i < list.length; i++) {
        if (identical(list[i].$1, loc.$1) && list[i].$2 == loc.$2) {
          idx = i;
          break;
        }
      }
    }
    final next = idx < 0
        ? (delta > 0 ? 0 : list.length - 1)
        : math.min(math.max(idx + delta, 0), list.length - 1);
    if (next == idx) return;
    final (v, i, mi) = list[next];
    final e = v.events[i];
    debugPrint('EJM editor: 方向键选择 m=$mi staff=${v.staff} index=$i');
    setState(() => _selected = e);
    _sheet.highlight(mi, v.staff - 1, i);
    _revealMeasure(mi, null);
  }

  void _deleteSelected() {
    final sel = _selected;
    if (sel == null) return;
    final loc = _locate(sel);
    if (loc == null) return;
    loc.$1.events.removeAt(loc.$2);
    debugPrint(
      'EJM editor: 删除 m=${loc.$3} staff=${loc.$1.staff} index=${loc.$2}',
    );
    setState(() => _selected = null);
    _afterChange();
  }

  Future<void> _editSelected() async {
    final sel = _selected;
    if (sel == null) return;
    final result = await _showEventDialog(sel, isNew: false);
    if (!mounted) return;
    if (result == false) {
      _deleteSelected();
    } else if (result == true) {
      _afterChange();
    }
  }

  // ---- 键盘输入 ----

  /// 焦点在文本框里、或对话框等路由覆盖在本页之上时不劫持按键。
  bool _keyboardBlocked() {
    if (ModalRoute.of(context)?.isCurrent != true) return true;
    final f = FocusManager.instance.primaryFocus;
    return f?.context?.widget is EditableText;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_keyboardBlocked()) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // 左右方向键：选择前一个/后一个事件
    if (key == LogicalKeyboardKey.arrowLeft) {
      _selectNeighbor(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _selectNeighbor(1);
      return KeyEventResult.handled;
    }
    // Insert：插入新音符（默认音 C，当前八度/时值）
    if (key == LogicalKeyboardKey.insert) {
      _insertPianoNote(('C', 0, 0));
      return KeyEventResult.handled;
    }
    // Z/X：降/升八度
    if (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.keyX) {
      final dir = key == LogicalKeyboardKey.keyX ? 1 : -1;
      setState(
        () => _inputOctave = math.min(math.max(_inputOctave + dir, 0), 8),
      );
      return KeyEventResult.handled;
    }
    // 1-6：时值（同步清零附点）
    const digitKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ];
    const numpadKeys = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
    ];
    var presetIdx = digitKeys.indexOf(key);
    if (presetIdx < 0) presetIdx = numpadKeys.indexOf(key);
    if (presetIdx >= 0) {
      setState(() {
        _inputDur = _durPresets[presetIdx].$2;
        _inputDots = 0;
      });
      return KeyEventResult.handled;
    }
    // . ：附点循环 0→1→2→0
    if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal) {
      setState(() => _inputDots = (_inputDots + 1) % 3);
      return KeyEventResult.handled;
    }
    // 0：插入休止符
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _insertEvent(false);
      return KeyEventResult.handled;
    }
    // 字母键：钢琴琴键输入
    final spec = _pianoKeys[key];
    if (spec != null) {
      _insertPianoNote(spec);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _durLabel() {
    for (final (name, d) in _durPresets) {
      if (d == _inputDur) return name;
    }
    return '$_inputDur';
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final navigator = Navigator.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || !_dirty) return;
          final discard = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('放弃修改？'),
              content: const Text('有未保存的修改，退出将丢失。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('继续编辑'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('放弃修改'),
                ),
              ],
            ),
          );
          if (discard == true && mounted) {
            navigator.pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('编辑曲谱'),
            actions: [
              IconButton(
                tooltip: '放弃修改并还原',
                icon: const Icon(Icons.restart_alt),
                onPressed: _dirty ? _reload : null,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
          body: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : doc == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildToolbar(),
                    _buildKeyboardHint(),
                    Expanded(flex: 5, child: _buildWebView()),
                    const Divider(height: 1),
                    _buildSelectionBar(),
                    Expanded(
                      flex: 4,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildMetaCard(doc),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ---- 谱面工具条 ----

  Widget _buildKeyboardHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Text(
        '键盘输入：A–L=白键 C–D₅，W/E/T/Y/U/O/P=黑键，Z/X=八度∓，'
        '1–6=时值，.=附点，0=休止，←/→=选音符，Insert=插入',
        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildToolbar() {
    // Wrap 而不是 Row+Spacer：窄窗口下按钮换行而不是被裁出屏幕外
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        IconButton(
          tooltip: '缩小',
          icon: const Icon(Icons.zoom_out),
          onPressed: () => _adjustZoom(-0.1),
        ),
        Text('${(_zoom * 100).round()}%', style: const TextStyle(fontSize: 13)),
        IconButton(
          tooltip: '放大',
          icon: const Icon(Icons.zoom_in),
          onPressed: () => _adjustZoom(0.1),
        ),
        OutlinedButton.icon(
          onPressed: () => _insertEvent(true),
          icon: const Icon(Icons.note_add, size: 18),
          label: const Text('插入音符', style: TextStyle(fontSize: 12)),
        ),
        OutlinedButton.icon(
          onPressed: () => _insertEvent(false),
          icon: const Icon(Icons.playlist_add, size: 18),
          label: const Text('插入休止', style: TextStyle(fontSize: 12)),
        ),
        OutlinedButton.icon(
          onPressed: _selected == null ? null : _deleteSelected,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('删除', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _adjustZoom(double delta) async {
    setState(() => _zoom = (_zoom + delta).clamp(0.5, 2.5));
    await _sheet.setZoom(_zoom);
  }

  Widget _buildSelectionBar() {
    final sel = _selected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _buildInputStateChip(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sel == null ? '点击上方谱面的音符或休止符进行编辑' : '已选中：${eventLabel(sel)}',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (sel != null)
            FilledButton.tonal(
              onPressed: _editSelected,
              child: const Text('编辑'),
            ),
        ],
      ),
    );
  }

  /// 当前键盘输入状态（八度/时值/附点），随按键实时更新。
  Widget _buildInputStateChip() {
    final dots = _inputDots > 0 ? '+$_inputDots附点' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Text(
        '八度$_inputOctave ${_durLabel()}$dots',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  // ---- WebView ----

  Widget _buildWebView() {
    _htmlFuture ??= buildSheetHostHtml();
    return FutureBuilder<String>(
      future: _htmlFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final html = snap.data!;
        return InAppWebView(
          initialData: InAppWebViewInitialData(
            data: html,
            mimeType: 'text/html',
            encoding: 'utf-8',
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: false,
            supportZoom: false,
            disableContextMenu: true,
          ),
          onWebViewCreated: (w) {
            _sheet.attach(w);
            w.addJavaScriptHandler(
              handlerName: 'ejm',
              callback: (args) {
                if (args.isNotEmpty && args.first is Map) {
                  final event = SheetEvent.from(args.first as Map);
                  _sheet.handleEvent(event);
                  _onSheetEvent(event);
                }
                return null;
              },
            );
          },
          onLoadStop: (_, _) async {
            await _sheet.pageReady;
            final doc = _doc;
            if (doc != null) {
              await _sheet.loadMusicXml(scoreToMusicXml(doc), zoom: _zoom);
            }
          },
        );
      },
    );
  }

  // ---- 元信息 ----

  static String _keyLabel(int f) {
    if (f == 0) return 'C（无升降号）';
    return f > 0 ? '$f 个升号' : '${-f} 个降号';
  }

  Widget _buildMetaCard(ScoreDocument doc) {
    final meta = doc.meta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('曲谱信息', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _labeledField(
                  '曲名',
                  180,
                  (v) => meta.title = v,
                  initial: meta.title,
                ),
                _labeledField(
                  '作曲/来源',
                  140,
                  (v) => meta.composer = v,
                  initial: meta.composer ?? '',
                ),
                _numField('BPM', 70, meta.bpm, (v) {
                  if (v != null) meta.bpm = v;
                }),
                _dropdown<int>('调号', meta.keyFifths, [
                  for (var f = -7; f <= 7; f++) (f, _keyLabel(f)),
                ], (v) => meta.keyFifths = v),
                _dropdown<String>(
                  '大小调',
                  meta.keyMode,
                  const [('major', '大调'), ('minor', '小调')],
                  (v) {
                    meta.keyMode = v;
                  },
                ),
                _dropdown<int>('拍号分子', meta.timeBeats, [
                  for (final b in [2, 3, 4, 5, 6, 7, 8, 9, 12]) (b, '$b'),
                ], (v) => meta.timeBeats = v),
                _dropdown<int>('拍号分母', meta.timeBeatType, [
                  for (final d in [2, 4, 8, 16]) (d, '$d'),
                ], (v) => meta.timeBeatType = v),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- 事件编辑对话框 ----

  /// 弹出事件编辑对话框，就地修改 [e]；返回是否确认（false=删除，null=取消）。
  Future<bool?> _showEventDialog(ScoreEvent e, {required bool isNew}) {
    var type = e.type;
    var dur = e.dur;
    var dots = e.dots;
    var tie = e.tie;
    // 音高编辑用副本，确认时写回
    final pitches = [
      for (final p in e.pitches)
        ScorePitch(
          step: p.step,
          alter: p.alter,
          octave: p.octave,
          finger: p.finger,
        ),
    ];
    if (pitches.isEmpty) {
      pitches.add(ScorePitch(step: 'C', alter: 0, octave: 4));
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(isNew ? '添加事件' : '编辑事件'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'note', label: Text('音符')),
                    ButtonSegment(value: 'rest', label: Text('休止')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setDialog(() => type = s.first),
                ),
                const SizedBox(height: 10),
                if (type == 'note')
                  for (var i = 0; i < pitches.length; i++)
                    _pitchRow(pitches, i, setDialog),
                if (type == 'note')
                  TextButton.icon(
                    onPressed: () => setDialog(() {
                      pitches.add(
                        ScorePitch(
                          step: 'C',
                          alter: 0,
                          octave: pitches.last.octave,
                        ),
                      );
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('加一个音（和弦）'),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final entry in kDurPresets.entries)
                      ChoiceChip(
                        label: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: dur == entry.value && dots == 0,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setDialog(() {
                          dur = entry.value;
                          dots = 0;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('附点'),
                    IconButton(
                      onPressed: dots > 0
                          ? () => setDialog(() => dots--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                    ),
                    Text('$dots'),
                    IconButton(
                      onPressed: dots < 2
                          ? () => setDialog(() => dots++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                    ),
                    const SizedBox(width: 16),
                    const Text('延音线'),
                    const SizedBox(width: 4),
                    DropdownButton<String?>(
                      value: tie,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('无')),
                        DropdownMenuItem(value: 'start', child: Text('开始')),
                        DropdownMenuItem(value: 'stop', child: Text('结束')),
                      ],
                      onChanged: (v) => setDialog(() => tie = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (!isNew)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('删除事件', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                e.type = type;
                e.dur = dur.reduced();
                e.dots = dots;
                e.tie = tie;
                e.pitches = type == 'note' ? pitches : [];
                Navigator.of(ctx).pop(true);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pitchRow(List<ScorePitch> pitches, int i, StateSetter setDialog) {
    final p = pitches[i];
    return Row(
      children: [
        DropdownButton<String>(
          value: p.step,
          items: [
            for (final s in kStepNames)
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) => setDialog(() => p.step = v!),
        ),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: p.alter,
          items: [
            for (final entry in kAlterNames.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (v) => setDialog(() => p.alter = v!),
        ),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: p.octave,
          items: [
            for (var o = 0; o <= 8; o++)
              DropdownMenuItem(value: o, child: Text('八度$o')),
          ],
          onChanged: (v) => setDialog(() => p.octave = v!),
        ),
        const Spacer(),
        if (pitches.length > 1)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16),
            tooltip: '移除该音',
            onPressed: () => setDialog(() => pitches.removeAt(i)),
          ),
      ],
    );
  }

  // ---- 表格小组件 ----

  Widget _labeledField(
    String label,
    double width,
    ValueChanged<String> onChanged, {
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) {
          onChanged(v);
          _afterChange();
        },
      ),
    );
  }

  Widget _numField(
    String label,
    double width,
    int? initial,
    ValueChanged<int?> onChanged,
  ) {
    final controller = TextEditingController(text: '${initial ?? ''}');
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) {
          onChanged(int.tryParse(v));
          _afterChange();
        },
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T? current,
    List<(T, String)> options,
    ValueChanged<T> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        DropdownButton<T>(
          value: current,
          items: [
            for (final (v, name) in options)
              DropdownMenuItem(value: v, child: Text(name)),
          ],
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
              _afterChange();
            }
          },
        ),
      ],
    );
  }
}
