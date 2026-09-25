import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ejmusic/core/config/app_settings.dart';
import 'package:ejmusic/core/db/database.dart';
import 'package:ejmusic/data/llm/llm_client.dart';
import 'package:ejmusic/data/score/score_store.dart';
import 'dart:typed_data';

import 'package:ejmusic/features/generation/logic/generation_controller.dart';
import 'package:ejmusic/features/generation/logic/generation_pipeline.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generation_pipeline_test.dart' show FakeGateway, goodFragment;

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('ejmusic_test_');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await tempDir.delete(recursive: true);
  });

  /// 建一首 2 页的曲子，返回 songId。
  Future<int> seedSong() async {
    final songId = await db.songsDao.insertSong(SongsCompanion.insert(
      title: '小星星',
      titleNorm: '小星星',
      kind: const Value('piano'),
      pageCount: const Value(2),
    ));
    for (var i = 0; i < 2; i++) {
      final imgId = await db.into(db.sourceImages).insert(
            SourceImagesCompanion.insert(
              absPath: '/fake/page_$i.jpg',
              fileName: 'page_$i.jpg',
              bytes: 100,
              mtimeMs: 0,
              groupId: 1,
              pageIndexInGroup: i,
            ),
          );
      await db.into(db.songPages).insert(
            SongPagesCompanion.insert(
              songId: songId,
              pageIndex: i,
              sourceImageId: imgId,
            ),
          );
    }
    return songId;
  }

  ProviderContainer makeContainer(LlmGateway gateway) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      pipelineProvider.overrideWithValue(GenerationPipeline(
        gateway: gateway,
        readImage: (_) async => Uint8List.fromList([1, 2, 3]),
        compress: (b) => b,
      )),
      scoreStoreProvider.overrideWith((ref) async => ScoreStore(tempDir.path)),
    ]);
    return c;
  }

  Map<String, dynamic> pageJson(int n) {
    final json = jsonDecode(jsonEncode(goodFragment)) as Map<String, dynamic>;
    json['page'] = n;
    return json;
  }

  test('start：全部成功 → ready + score.json/musicxml 落盘 + meta 回填',
      () async {
    final songId = await seedSong();
    final gateway = FakeGateway([
      jsonEncode(pageJson(1)),
      jsonEncode(pageJson(2)),
    ]);
    container = makeContainer(gateway);

    await container
        .read(generationControllerProvider(songId).notifier)
        .start();

    final song = await db.songsDao.songById(songId);
    expect(song.status, 'ready');
    expect(song.scorePath, isNotNull);
    expect(File(song.scorePath!).existsSync(), isTrue);
    expect(File(song.musicxmlCachePath!).existsSync(), isTrue);
    expect(song.bpm, 100);
    expect(song.timeBeats, 4);

    final xml = await File(song.musicxmlCachePath!).readAsString();
    expect(xml, contains('<score-partwise'));
    final doc = await ScoreStore(tempDir.path).load(songId);
    expect(doc, isNotNull);
    expect(doc!.parts.first.measures.length, 2);

    final pages = await db.songsDao.pagesOfSong(songId);
    expect(pages.every((p) => p.llmStatus == 'ok'), isTrue);

    final state = container.read(generationControllerProvider(songId));
    expect(state.resultMessage, contains('制作完成'));
  });

  test('start：全部失败 → failed + 错误信息', () async {
    final songId = await seedSong();
    final gateway = FakeGateway([
      Exception('网络错误'),
      Exception('网络错误'),
      Exception('网络错误'),
      Exception('网络错误'),
      Exception('网络错误'),
      Exception('网络错误'),
    ]);
    container = makeContainer(gateway);

    await container
        .read(generationControllerProvider(songId).notifier)
        .start();

    final song = await db.songsDao.songById(songId);
    expect(song.status, 'failed');
    expect(song.errorMsg, isNotNull);
    final pages = await db.songsDao.pagesOfSong(songId);
    expect(pages.every((p) => p.llmStatus == 'failed'), isTrue);
  });

  test('单页失败 → partial；retryPage 修复后 → ready', () async {
    final songId = await seedSong();
    final gateway = FakeGateway([
      jsonEncode(pageJson(1)),
      '{"bad', '{"bad', '{"bad', // 第 2 页 3 次全失败
    ]);
    container = makeContainer(gateway);

    await container
        .read(generationControllerProvider(songId).notifier)
        .start();

    var song = await db.songsDao.songById(songId);
    expect(song.status, 'partial');

    // 换一个好网关重试第 2 页
    final goodGateway = FakeGateway([jsonEncode(pageJson(2))]);
    container.dispose();
    container = makeContainer(goodGateway);

    await container
        .read(generationControllerProvider(songId).notifier)
        .retryPage(2);

    song = await db.songsDao.songById(songId);
    expect(song.status, 'ready');
    expect(song.scorePath, isNotNull);

    final doc = await ScoreStore(tempDir.path).load(songId);
    expect(doc!.parts.first.measures.length, 2);

    final pages = await db.songsDao.pagesOfSong(songId);
    expect(pages.every((p) => p.llmStatus == 'ok'), isTrue);
  });
}
