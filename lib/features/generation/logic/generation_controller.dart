import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../data/llm/llm_client.dart';
import '../../../data/score/score_store.dart';
import '../../../domain/score/merge/page_merger.dart';
import '../../../domain/score/score_document.dart';
import '../../../domain/score/score_validator.dart';
import '../../library/library_providers.dart';
import 'generation_pipeline.dart';

/// LLM 网关（测试可 override）。
final llmGatewayProvider = Provider<LlmGateway>((ref) {
  return DioLlmClient(
    loadConfig: () =>
        ref.read(llmConfigProvider).value ?? LlmConfig.defaults(),
  );
});

final scoreStoreProvider = FutureProvider<ScoreStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return ScoreStore(dir.path);
});

/// 识别管线（测试 override：注入 fake gateway / 图片读取）。
final pipelineProvider = Provider<GenerationPipeline>((ref) {
  return GenerationPipeline(gateway: ref.read(llmGatewayProvider));
});

class GenerationPageState {
  GenerationPageState({
    required this.songId,
    this.pages = const [],
    this.running = false,
    this.error,
    this.resultMessage,
  });

  final int songId;
  final List<PageProgress> pages;
  final bool running;
  final String? error;
  final String? resultMessage;

  int get okCount => pages.where((p) => p.status == 'ok').length;

  GenerationPageState copyWith({
    List<PageProgress>? pages,
    bool? running,
    String? error,
    String? resultMessage,
  }) =>
      GenerationPageState(
        songId: songId,
        pages: pages ?? this.pages,
        running: running ?? this.running,
        error: error,
        resultMessage: resultMessage,
      );
}

/// 制作流程编排：逐页识别（DB 记录进度/断点）→ 合并 → 落盘 → 更新曲目。
class GenerationController extends Notifier<GenerationPageState> {
  GenerationController(this.songId);

  final int songId;

  @override
  GenerationPageState build() => GenerationPageState(songId: songId);

  AppDatabase get _db => ref.read(appDatabaseProvider);

  /// 开始/重新制作全部页。
  Future<void> start() async {
    final song = await _db.songsDao.songById(songId);
    if (song.status == SongStatus.generating.name) return;

    await _db.songsDao.updateStatus(songId, SongStatus.generating);
    ref.invalidate(songsStreamProvider);

    final pageRows = await _db.songsDao.pagesWithImages(songId);
    if (pageRows.isEmpty) {
      await _db.songsDao.updateStatus(
        songId,
        SongStatus.failed,
        errorMsg: '没有可识别的页面',
      );
      state = state.copyWith(
        running: false,
        error: '没有可识别的页面',
        resultMessage: null,
      );
      return;
    }

    state = state.copyWith(
      running: true,
      error: null,
      resultMessage: null,
      pages: [
        for (final r in pageRows)
          PageProgress(pageIndex: r.page.pageIndex + 1,
              status: r.page.llmStatus == 'ok' ? 'ok' : 'pending'),
      ],
    );

    final store = await ref.read(scoreStoreProvider.future);
    await store.deleteFragments(songId);

    await _run(
      kind: song.kind,
      inputs: [
        for (final r in pageRows)
          PageInput(pageIndex: r.page.pageIndex + 1, imagePath: r.image.absPath),
      ],
      pageIds: [for (final r in pageRows) r.page.id],
    );
  }

  /// 单页重试：重识别该页，与已保存片段重新合并。
  Future<void> retryPage(int pageIndex) async {
    final song = await _db.songsDao.songById(songId);
    final pageRows = await _db.songsDao.pagesWithImages(songId);
    final target = pageRows.where((r) => r.page.pageIndex + 1 == pageIndex).toList();
    if (target.isEmpty) return;
    final row = target.single;

    state = state.copyWith(running: true, error: null, resultMessage: null);
    _updatePage(pageIndex, (p) {
      p.status = 'running';
      p.error = null;
    });

    final store = await ref.read(scoreStoreProvider.future);
    final existing = await store.loadFragments(songId);

    await _run(
      kind: song.kind,
      inputs: [
        PageInput(pageIndex: pageIndex, imagePath: row.image.absPath),
      ],
      pageIds: [row.page.id],
      presetFragments: [
        for (final f in existing)
          if (f.page != pageIndex) f,
      ],
    );
  }

  Future<void> _run({
    required String kind,
    required List<PageInput> inputs,
    required List<int> pageIds,
    List<PageFragment> presetFragments = const [],
  }) async {
    final songId = this.songId;
    final store = await ref.read(scoreStoreProvider.future);
    final pipeline = ref.read(pipelineProvider);

    try {
      final result = await pipeline.run(
        kind: kind,
        pages: inputs,
        onProgress: (p) => _updatePage(p.pageIndex, (np) {
          np.status = p.status;
          np.attempts = p.attempts;
          np.error = p.error;
        }),
      );

      // DB 页状态 + 片段落盘
      for (var i = 0; i < result.pages.length; i++) {
        final o = result.pages[i];
        await _db.songsDao.updatePageLlmResult(
          pageId: pageIds[i],
          status: o.ok ? PageLlmStatus.ok : PageLlmStatus.failed,
          attempts: o.attempts,
          error: o.error,
        );
        if (o.ok && o.fragment != null) {
          await store.saveFragment(songId, o.fragment!);
        }
      }

      // 与既有片段合并（单页重试场景）
      final allFragments = [
        ...presetFragments,
        for (final o in result.pages)
          if (o.ok && o.fragment != null) o.fragment!,
      ]..sort((a, b) => a.page.compareTo(b.page));

      String? message;
      String? error;
      if (allFragments.isEmpty) {
        await _db.songsDao.updateStatus(
          songId,
          SongStatus.failed,
          errorMsg: [for (final o in result.pages) o.error].join('\n'),
        );
        error = '全部页面识别失败';
      } else {
        final merged = PageMerger.merge(fragments: allFragments, kind: kind);
        final doc = merged.document;
        doc.meta.pageCount = inputs.length;
        final validation = ScoreValidator.validateAndRepair(doc);
        doc.meta.imageNames = [for (final i in inputs) i.imagePath];

        final paths = await store.save(songId, doc);
        final allOk = result.allOk;
        await _db.songsDao.updateScoreResult(
          songId: songId,
          status: allOk ? SongStatus.ready : SongStatus.partial,
          composer: doc.meta.composer,
          keyFifths: doc.meta.keyFifths,
          timeBeats: doc.meta.timeBeats,
          timeBeatType: doc.meta.timeBeatType,
          bpm: doc.meta.bpm,
          scorePath: paths.scorePath,
          musicxmlCachePath: paths.musicXmlPath,
          errorMsg: allOk
              ? null
              : '第 ${[for (final o in result.pages) if (!o.ok) o.pageIndex].join('、')} 页识别失败，可单独重试',
        );
        message = allOk
            ? '制作完成：${doc.parts.first.measures.length} 小节'
            : '部分完成（${result.okCount}/${result.pages.length} 页），失败页可重试';
        if (validation.errors.isNotEmpty) {
          error = '校验警告：${validation.errors.first.message}';
        }
      }

      state = state.copyWith(
        running: false,
        error: error,
        resultMessage: message,
      );
      ref.invalidate(songsStreamProvider);
      ref.invalidate(songProvider(songId));
    } catch (e) {
      await _db.songsDao.updateStatus(songId, SongStatus.failed, errorMsg: e.toString());
      state = state.copyWith(running: false, error: e.toString());
      ref.invalidate(songsStreamProvider);
    }
  }

  void _updatePage(int pageIndex, void Function(PageProgress p) mutate) {
    final pages = [for (final p in state.pages) p.copy()];
    for (final p in pages) {
      if (p.pageIndex == pageIndex) mutate(p);
    }
    state = state.copyWith(pages: pages);
  }
}

final generationControllerProvider =
    NotifierProvider.family<GenerationController, GenerationPageState, int>(
  GenerationController.new,
);
