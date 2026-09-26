import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
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

  @override
  void initState() {
    super.initState();
    EditorPage.debugSheet = _sheet;
    _reload();
  }

  @override
  void dispose() {
    EditorPage.debugSheet = null;
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
    try {
      await _sheet.setZoom(_zoom);
      await _sheet.loadMusicXml(scoreToMusicXml(doc));
    } catch (_) {
      // 渲染错误经 SheetError 事件上报
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
    if (click.measure < 0 || click.measure >= measures.length) return;
    final measure = measures[click.measure];
    ScoreVoice? voice;
    for (final v in measure.voices) {
      if (v.staff == click.staff + 1) {
        voice = v;
        break;
      }
    }
    if (voice == null || click.eventIndex >= voice.events.length) return;
    final event = voice.events[click.eventIndex];
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
        EditorPage.debugSelectedStep = event.eventIndex;
        _onNoteClicked(event);
      case SheetError(:final message):
        setState(() => _error = '渲染失败：$message');
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

  (ScoreVoice, int)? _locate(ScoreEvent e) {
    final doc = _doc;
    if (doc == null) return null;
    for (final m in doc.parts.first.measures) {
      for (final v in m.voices) {
        final i = v.events.indexOf(e);
        if (i >= 0) return (v, i);
      }
    }
    return null;
  }

  void _insertEvent(bool note) {
    final doc = _doc;
    if (doc == null) return;
    final e = ScoreEvent(
      type: note ? 'note' : 'rest',
      dur: const Rational(1, 1),
      pitches: note ? [ScorePitch(step: 'C', alter: 0, octave: 4)] : [],
    );
    final sel = _selected;
    final loc = sel == null ? null : _locate(sel);
    if (loc != null) {
      loc.$1.events.insert(loc.$2 + 1, e);
    } else {
      doc.parts.first.measures.last.voices.last.events.add(e);
    }
    setState(() => _selected = e);
    _afterChange();
  }

  void _deleteSelected() {
    final sel = _selected;
    if (sel == null) return;
    final loc = _locate(sel);
    if (loc == null) return;
    loc.$1.events.removeAt(loc.$2);
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

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final navigator = Navigator.of(context);
    return PopScope(
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
    );
  }

  // ---- 谱面工具条 ----

  Widget _buildToolbar() {
    return Row(
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
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => _insertEvent(true),
          icon: const Icon(Icons.note_add, size: 18),
          label: const Text('插入音符', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _insertEvent(false),
          icon: const Icon(Icons.playlist_add, size: 18),
          label: const Text('插入休止', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _selected == null ? null : _deleteSelected,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('删除', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
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
            await _sheet.setZoom(_zoom);
            final doc = _doc;
            if (doc != null) {
              await _sheet.loadMusicXml(scoreToMusicXml(doc));
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
