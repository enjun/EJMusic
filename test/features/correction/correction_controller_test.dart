import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ejmusic/core/config/app_settings.dart';
import 'package:ejmusic/core/db/database.dart';
import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/data/score/score_store.dart';
import 'package:ejmusic/domain/score/merge/page_merger.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:ejmusic/features/correction/logic/correction_controller.dart';
import 'package:ejmusic/features/correction/logic/correction_pipeline.dart';
import 'package:ejmusic/features/generation/logic/generation_controller.dart'
    show scoreStoreProvider;

import 'package:ejmusic/features/library/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'correction_pipeline_test.dart' show FakeGateway;

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

  /// 建一首 2 页曲子并落盘 score.json + 页片段。
  /// 每页 1 个小节：staff1 四个四分音符 + staff2 全小节休止。
  Future<int> seedSong() async {
    final songId = await db.songsDao.insertSong(SongsCompanion.insert(
      title: '小星星',
      titleNorm: '小星星',
      kind: const Value('piano'),
      pageCount: const Value(2),
    ));
    final store = ScoreStore(tempDir.path);
    final frags = <PageFragment>[];
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
      frags.add(PageFragment(
        page: i + 1,
        title: '小星星',
        keyFifths: 0,
        timeBeats: 4,
        timeBeatType: 4,
        bpm: 88,
        measures: [
          ScoreMeasure(number: i + 1, voices: [
            ScoreVoice(staff: 1, voiceNo: 1, events: [
              for (final step in ['C', 'D', 'E', 'F'])
                ScoreEvent(
                    type: 'note',
                    dur: const Rational(1, 1),
                    pitches: [ScorePitch(step: step, octave: 4)]),
            ]),
            ScoreVoice(staff: 2, voiceNo: 1, events: [
              ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
            ]),
          ]),
        ],
      ));
      await store.saveFragment(songId, frags.last);
    }
    final merged = PageMerger.merge(fragments: frags, kind: 'piano');
    await store.save(songId, merged.document);
    return songId;
  }

  /// LLM 返回的页片段 JSON：steps 覆盖 staff1 的四个音高。
  String pageJson(int page, List<String> steps) => jsonEncode({
        'page': page,
        'title': '小星星',
        'keyFifths': 0,
        'timeBeats': 4,
        'timeBeatType': 4,
        'bpm': 88,
        'measures': [
          {
            'number': page,
            'voices': [
              {
                'staff': 1,
                'events': [
                  for (final step in steps)
                    {
                      'type': 'note',
                      'dur': {'n': 1, 'd': 1},
                      'pitches': [
                        {'step': step, 'alter': 0, 'octave': 4}
                      ]
                    },
                ]
              },
              {
                'staff': 2,
                'events': [
                  {
                    'type': 'rest',
                    'dur': {'n': 4, 'd': 1}
                  }
                ]
              }
            ]
          }
        ],
      });

  ProviderContainer makeContainer(FakeGateway gateway) {
    return ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      correctionPipelineProvider.overrideWith((ref) async => CorrectionPipeline(
            gateway: gateway,
            readImage: (_) async => Uint8List.fromList([1, 2, 3]),
            compress: (b) => b,
          )),
      scoreStoreProvider.overrideWith((ref) async => ScoreStore(tempDir.path)),
      songsStreamProvider.overrideWith((ref) => const Stream.empty()),
    ]);
  }

  test('start → review → applySelected 后 score.json 含改动', () async {
    final songId = await seedSong();
    // 第 1 页发现一个错音（D4→G4），第 2 页无修改
    final gateway = FakeGateway([
      pageJson(1, ['C', 'G', 'E', 'F']),
      pageJson(2, ['C', 'D', 'E', 'F']),
    ]);
    container = makeContainer(gateway);

    await container
        .read(correctionControllerProvider(songId).notifier)
        .start();

    var state = container.read(correctionControllerProvider(songId));
    expect(state.stage, CorrectionStage.review);
    expect(state.changes.length, 1);
    expect(state.changes.single.page, 1);
    expect(state.pages[0].status, 'ok');
    expect(state.pages[1].status, 'unchanged');
    expect(state.selectedCount, 1);

    await container
        .read(correctionControllerProvider(songId).notifier)
        .applySelected();

    state = container.read(correctionControllerProvider(songId));
    expect(state.resultMessage, contains('已应用 1 处修改'));

    final doc = await ScoreStore(tempDir.path).load(songId);
    expect(doc, isNotNull);
    final events = doc!.parts.first.measures[0].voices.first.events;
    expect(events[1].pitches.first.step, 'G', reason: '改动已落盘');
    expect(events[0].pitches.first.step, 'C', reason: '其余事件不受影响');
    // 第 2 页小节未被动过
    expect(doc.parts.first.measures[1].voices.first.events[3].pitches.first.step,
        'F');
  });

  test('取消勾选的改动不应用', () async {
    final songId = await seedSong();
    final gateway = FakeGateway([
      pageJson(1, ['G', 'G', 'G', 'G']), // 4 处改动
      pageJson(2, ['C', 'D', 'E', 'F']),
    ]);
    container = makeContainer(gateway);

    final controller =
        container.read(correctionControllerProvider(songId).notifier);
    await controller.start();
    var state = container.read(correctionControllerProvider(songId));
    expect(state.changes.length, 4);

    controller.toggle(0); // 取消第 1 处
    state = container.read(correctionControllerProvider(songId));
    expect(state.selectedCount, 3);

    await controller.applySelected();
    final doc = await ScoreStore(tempDir.path).load(songId);
    final events = doc!.parts.first.measures[0].voices.first.events;
    expect(events[0].pitches.first.step, 'C', reason: '未勾选不落盘');
    expect(events[1].pitches.first.step, 'G');
  });

  test('无曲谱数据 → start 失败带错误信息', () async {
    final songId = await seedSong();
    // 删掉 score.json
    await File(ScoreStore(tempDir.path).scorePath(songId)).delete();
    final gateway = FakeGateway([]);
    container = makeContainer(gateway);

    await container
        .read(correctionControllerProvider(songId).notifier)
        .start();

    final state = container.read(correctionControllerProvider(songId));
    expect(state.stage, CorrectionStage.idle);
    expect(state.error, isNotNull);
  });
}
