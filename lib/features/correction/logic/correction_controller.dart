import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart' show appDatabaseProvider;
import '../../../core/db/database.dart';
import '../../../data/score/score_store.dart';
import '../../../domain/score/correct/score_diff.dart';
import '../../../domain/score/correct/slice_map.dart';
import '../../../domain/score/merge/page_merger.dart';
import '../../../domain/score/score_document.dart';
import '../../editor/logic/score_editor.dart';
import '../../generation/logic/generation_controller.dart'
    show llmGatewayProvider, scoreStoreProvider;
import '../../generation/logic/generation_pipeline.dart' show PageInput;
import '../../library/library_providers.dart';
import 'correction_pipeline.dart';

/// 纠错管线（测试可 override：注入 fake gateway / 图片读取）。
final correctionPipelineProvider = Provider<CorrectionPipeline>((ref) {
  return CorrectionPipeline(gateway: ref.read(llmGatewayProvider));
});

/// 一次纠错会话的准备数据（详情页与编辑器入口共用）。
class CorrectionSession {
  CorrectionSession({
    required this.songId,
    required this.kind,
    required this.doc,
    required this.slices,
    required this.pages,
    required this.songMeta,
  });

  final int songId;
  final String kind;

  /// 纠错基准谱（深拷贝快照，apply 前不被修改）。
  final ScoreDocument doc;
  final List<PageSliceSpec> slices;
  final List<PageInput> pages;

  /// 应用后回写 DB 元数据用（与编辑器保存语义一致）。
  final Song songMeta;
}

/// 两个入口共用的准备步骤：加载当前谱 → 片段重合并出页规格 → 页图列表。
///
/// [baseDoc] 为 null 时从磁盘加载（详情页）；编辑器传当前 `_doc`，
/// 未保存的手动改动参与纠错。
Future<CorrectionSession> prepareCorrection({
  required ScoreStore store,
  required AppDatabase db,
  required int songId,
  ScoreDocument? baseDoc,
}) async {
  final song = await db.songsDao.songById(songId);
  final doc = baseDoc ?? await store.load(songId);
  if (doc == null) {
    throw StateError('曲谱数据缺失，请先制作曲谱');
  }
  final fragments = await store.loadFragments(songId);
  final slices = loadSliceSpecs(
    fragments: fragments,
    current: doc,
    kind: song.kind,
  );
  final pageRows = await db.songsDao.pagesWithImages(songId);
  if (pageRows.isEmpty) {
    throw StateError('没有可用的页面图片');
  }
  return CorrectionSession(
    songId: songId,
    kind: song.kind,
    doc: doc,
    slices: slices,
    pages: [
      for (final r in pageRows)
        PageInput(pageIndex: r.page.pageIndex + 1, imagePath: r.image.absPath),
    ],
    songMeta: song,
  );
}

/// 纠错会话状态（详情页整页流程用；编辑器入口直接编排不经过这里）。
enum CorrectionStage { idle, running, review }

class CorrectionState {
  CorrectionState({
    this.stage = CorrectionStage.idle,
    this.pages = const [],
    this.changes = const [],
    this.warnings = const [],
    this.error,
    this.resultMessage,
    this.applying = false,
  });

  final CorrectionStage stage;
  final List<CorrectionPageProgress> pages;
  final List<ScoreChange> changes;

  /// 告警（带 "第N页 " 前缀便于单页重试时替换）。
  final List<String> warnings;
  final String? error;
  final String? resultMessage;
  final bool applying;

  int get selectedCount => changes.where((c) => c.selected).length;

  CorrectionState copyWith({
    CorrectionStage? stage,
    List<CorrectionPageProgress>? pages,
    List<ScoreChange>? changes,
    List<String>? warnings,
    String? error,
    String? resultMessage,
    bool? applying,
  }) =>
      CorrectionState(
        stage: stage ?? this.stage,
        pages: pages ?? this.pages,
        changes: changes ?? this.changes,
        warnings: warnings ?? this.warnings,
        error: error,
        resultMessage: resultMessage,
        applying: applying ?? this.applying,
      );
}

/// 详情页一键纠错编排：start → 进度 → review → applySelected。
class CorrectionController extends Notifier<CorrectionState> {
  CorrectionController(this.songId);

  final int songId;

  CorrectionSession? _session;

  @override
  CorrectionState build() => CorrectionState();

  AppDatabase get _db => ref.read(appDatabaseProvider);

  /// 开始全曲纠错。
  Future<void> start() async {
    if (state.stage == CorrectionStage.running) return;
    state = CorrectionState(stage: CorrectionStage.running);
    try {
      final store = await ref.read(scoreStoreProvider.future);
      final session = await prepareCorrection(
        store: store,
        db: _db,
        songId: songId,
      );
      _session = session;
      state = state.copyWith(
        pages: [
          for (final p in session.pages)
            CorrectionPageProgress(pageIndex: p.pageIndex),
        ],
        error: null,
        resultMessage: null,
      );
      final pipeline = ref.read(correctionPipelineProvider);
      final result = await pipeline.run(
        kind: session.kind,
        doc: session.doc,
        slices: session.slices,
        pages: session.pages,
        onProgress: (p) => _updatePage(p.pageIndex, (np) {
          np.status = p.status;
          np.attempts = p.attempts;
          np.error = p.error;
          np.changeCount = p.changeCount;
          np.largeDiff = p.largeDiff;
        }),
      );
      state = state.copyWith(
        stage: CorrectionStage.review,
        changes: result.changes,
        warnings: [
          for (final o in result.pages)
            for (final w in o.warnings) '第${o.pageIndex}页 $w',
        ],
      );
    } catch (e) {
      state = state.copyWith(stage: CorrectionStage.idle, error: e.toString());
    }
  }

  /// 单页重试：只重跑该页，替换其改动与告警，其余页保留。
  Future<void> retryPage(int pageIndex) async {
    final session = _session;
    if (session == null || state.stage == CorrectionStage.running) return;
    final page =
        session.pages.where((p) => p.pageIndex == pageIndex).firstOrNull;
    if (page == null) return;
    state = state.copyWith(stage: CorrectionStage.running);
    _updatePage(pageIndex, (p) {
      p.status = 'running';
      p.error = null;
    });
    try {
      final outcome = await ref.read(correctionPipelineProvider).runPage(
            kind: session.kind,
            doc: session.doc,
            slices: session.slices,
            page: page,
            onProgress: (p) => _updatePage(p.pageIndex, (np) {
              np.status = p.status;
              np.attempts = p.attempts;
              np.error = p.error;
              np.changeCount = p.changeCount;
              np.largeDiff = p.largeDiff;
            }),
          );
      final prefix = '第$pageIndex页 ';
      state = state.copyWith(
        stage: CorrectionStage.review,
        changes: [
          for (final c in state.changes)
            if (c.page != pageIndex) c,
          ...outcome.changes,
        ],
        warnings: [
          for (final w in state.warnings)
            if (!w.startsWith(prefix)) w,
          for (final w in outcome.warnings) '$prefix$w',
        ],
      );
    } catch (e) {
      _updatePage(pageIndex, (p) {
        p.status = 'failed';
        p.error = e.toString();
      });
      state = state.copyWith(stage: CorrectionStage.review);
    }
  }

  void toggle(int index) {
    final changes = [...state.changes];
    if (index < 0 || index >= changes.length) return;
    changes[index].selected = !changes[index].selected;
    state = state.copyWith(changes: changes);
  }

  void setAll(bool selected) {
    final changes = [...state.changes];
    for (final c in changes) {
      c.selected = selected;
    }
    state = state.copyWith(changes: changes);
  }

  /// 应用选中的改动：快照 → applyChanges → 校验落盘（与编辑器保存
  /// 完全同一语义：saveEditedScore + updateScoreMeta）。
  Future<void> applySelected() async {
    final session = _session;
    if (session == null || state.applying) return;
    final selected = [
      for (final c in state.changes)
        if (c.selected) c,
    ];
    if (selected.isEmpty) return;
    state = state.copyWith(applying: true, error: null);
    try {
      final doc = cloneDocument(session.doc);
      applyChanges(doc, selected);
      final result = await saveEditedScore(
        store: await ref.read(scoreStoreProvider.future),
        songId: songId,
        doc: doc,
      );
      final song = session.songMeta;
      await _db.songsDao.updateScoreMeta(
        songId: songId,
        title: song.title,
        composer: song.composer,
        keyFifths: song.keyFifths,
        timeBeats: song.timeBeats,
        timeBeatType: song.timeBeatType,
        bpm: song.bpm,
      );
      ref.invalidate(songsStreamProvider);
      ref.invalidate(songProvider(songId));
      state = state.copyWith(
        applying: false,
        stage: CorrectionStage.idle,
        changes: [],
        resultMessage: result.errors.isNotEmpty
            ? '已应用 ${selected.length} 处修改（有问题未修复：'
                '${result.errors.take(2).join('；')}）'
            : '已应用 ${selected.length} 处修改',
      );
    } catch (e) {
      state = state.copyWith(applying: false, error: e.toString());
    }
  }

  void _updatePage(
      int pageIndex, void Function(CorrectionPageProgress p) mutate) {
    final pages = [for (final p in state.pages) p.copy()];
    for (final p in pages) {
      if (p.pageIndex == pageIndex) mutate(p);
    }
    state = state.copyWith(pages: pages);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final x in this) {
      return x;
    }
    return null;
  }
}

final correctionControllerProvider =
    NotifierProvider.family<CorrectionController, CorrectionState, int>(
  CorrectionController.new,
);
