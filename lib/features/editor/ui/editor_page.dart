import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/util/rational.dart';
import '../../../domain/score/score_document.dart';
import '../../generation/logic/generation_controller.dart';
import '../../library/library_providers.dart';
import '../logic/score_editor.dart';

/// 曲谱手动编辑页：直接改 EJScore（音符/休止/时值/小节属性/元信息），
/// 保存时校验+修复并重生成 MusicXML 缓存。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.songId});

  final int songId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  ScoreDocument? _doc;
  String? _error;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _reload();
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
      });
    } catch (e) {
      setState(() => _error = e.toString());
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
          doc: doc);
      await ref.read(appDatabaseProvider).songsDao.updateScoreMeta(
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
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
                  child: const Text('继续编辑')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('放弃修改')),
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
                        child: CircularProgressIndicator(strokeWidth: 2))
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
                    child: Text(_error!, textAlign: TextAlign.center)))
            : doc == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildMetaCard(doc),
                      for (final m in doc.parts.first.measures)
                        _buildMeasureCard(doc, m),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }

  // dirty 翻转要触发重建，否则 PopScope 的 canPop 拿不到新值
  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  static String _keyLabel(int f) {
    if (f == 0) return 'C（无升降号）';
    return f > 0 ? '$f 个升号' : '${-f} 个降号';
  }

  // ---- 元信息 ----

  Widget _buildMetaCard(ScoreDocument doc) {
    final meta = doc.meta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('曲谱信息',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, children: [
              _labeledField('曲名', 180, (v) => meta.title = v, initial: meta.title),
              _labeledField('作曲/来源', 140, (v) => meta.composer = v,
                  initial: meta.composer ?? ''),
              _numField('BPM', 70, meta.bpm, (v) {
                if (v != null) meta.bpm = v;
              }),
              _dropdown<int>('调号', meta.keyFifths, [
                for (var f = -7; f <= 7; f++) (f, _keyLabel(f))
              ], (v) => meta.keyFifths = v),
              _dropdown<String>('大小调', meta.keyMode,
                  const [('major', '大调'), ('minor', '小调')], (v) {
                meta.keyMode = v;
              }),
              _dropdown<int>('拍号分子', meta.timeBeats, [
                for (final b in [2, 3, 4, 5, 6, 7, 8, 9, 12]) (b, '$b')
              ], (v) => meta.timeBeats = v),
              _dropdown<int>('拍号分母', meta.timeBeatType,
                  [for (final d in [2, 4, 8, 16]) (d, '$d')],
                  (v) => meta.timeBeatType = v),
            ]),
          ],
        ),
      ),
    );
  }

  // ---- 小节与事件 ----

  Widget _buildMeasureCard(ScoreDocument doc, ScoreMeasure m) {
    final part = doc.parts.first;
    final index = part.measures.indexOf(m);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('第 $index 小节',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (m.cont) const SizedBox(width: 6),
              if (m.cont) const Chip(label: Text('跨页承接'), visualDensity: VisualDensity.compact),
              const Spacer(),
              if (m.attributes != null && !m.attributes!.isEmpty)
                const Text('有本小节属性', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            for (final v in m.voices)
              _buildVoiceRow(m, v, part.staffCount),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRow(ScoreMeasure m, ScoreVoice v, int staffCount) {
    final name = staffCount > 1
        ? (v.staff == 1 ? '右手' : '左手')
        : '声部';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in v.events)
                  ActionChip(
                    label: Text(eventLabel(e), style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        e.isRest ? Colors.grey.shade200 : null,
                    onPressed: () => _editEvent(m, v, e),
                  ),
                ActionChip(
                  label: const Text('+音符', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addEvent(m, v, true),
                ),
                ActionChip(
                  label: const Text('+休止', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addEvent(m, v, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- 事件编辑 ----

  Future<void> _addEvent(ScoreMeasure m, ScoreVoice v, bool note) async {
    final e = ScoreEvent(
      type: note ? 'note' : 'rest',
      dur: const Rational(1, 1),
      pitches: note
          ? [ScorePitch(step: 'C', alter: 0, octave: 4)]
          : [],
    );
    final ok = await _showEventDialog(e, isNew: true);
    if (ok == true) {
      setState(() {
        v.events.add(e);
        _markDirty();
      });
    }
  }

  Future<void> _editEvent(ScoreMeasure m, ScoreVoice v, ScoreEvent e) async {
    final result = await _showEventDialog(e, isNew: false);
    if (result == false) {
      // 删除事件
      setState(() {
        v.events.remove(e);
        _markDirty();
      });
    } else if (result == true) {
      setState(() => _markDirty());
    }
  }

  /// 弹出事件编辑对话框，就地修改 [e]；返回是否确认。
  Future<bool?> _showEventDialog(ScoreEvent e, {required bool isNew}) {
    var type = e.type;
    var dur = e.dur;
    var dots = e.dots;
    var tie = e.tie;
    // 音高编辑用副本，确认时写回
    final pitches = [
      for (final p in e.pitches)
        ScorePitch(step: p.step, alter: p.alter, octave: p.octave, finger: p.finger),
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
                      pitches.add(ScorePitch(step: 'C', alter: 0, octave: pitches.last.octave));
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
                        label: Text(entry.key, style: const TextStyle(fontSize: 11)),
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
                Row(children: [
                  const Text('附点'),
                  IconButton(
                      onPressed: dots > 0
                          ? () => setDialog(() => dots--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 18)),
                  Text('$dots'),
                  IconButton(
                      onPressed: dots < 2
                          ? () => setDialog(() => dots++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline, size: 18)),
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
                ]),
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
                child: const Text('取消')),
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
    return Row(children: [
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
          for (var o = 0; o <= 8; o++) DropdownMenuItem(value: o, child: Text('八度$o')),
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
    ]);
  }

  // ---- 表格小组件 ----

  Widget _labeledField(String label, double width,
      ValueChanged<String> onChanged, {required String initial}) {
    final controller = TextEditingController(text: initial);
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) {
          onChanged(v);
          _markDirty();
        },
      ),
    );
  }

  Widget _numField(String label, double width, int? initial,
      ValueChanged<int?> onChanged) {
    final controller = TextEditingController(text: '${initial ?? ''}');
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) {
          onChanged(int.tryParse(v));
          _markDirty();
        },
      ),
    );
  }

  Widget _dropdown<T>(String label, T? current, List<(T, String)> options,
      ValueChanged<T> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      DropdownButton<T>(
        value: current,
        items: [
          for (final (v, name) in options) DropdownMenuItem(value: v, child: Text(name)),
        ],
        onChanged: (v) {
          if (v != null) {
            onChanged(v);
            _markDirty();
          }
        },
      ),
    ]);
  }
}
