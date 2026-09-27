import 'dart:convert';
import 'dart:typed_data';

import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/data/llm/llm_client.dart';
import 'package:ejmusic/domain/score/merge/page_merger.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:ejmusic/features/correction/logic/correction_pipeline.dart';
import 'package:ejmusic/features/generation/logic/generation_pipeline.dart'
    show PageInput;
import 'package:flutter_test/flutter_test.dart';

/// LLM 响应脚本（mock 回放）。
class FakeGateway implements LlmGateway {
  FakeGateway(this.outputs);
  final List<Object> outputs; // String 或 Exception
  final List<String> users = [];
  int call = 0;

  @override
  Future<String> completeJson({
    required String system,
    required String user,
    required List<String> imageJpegBase64,
  }) async {
    users.add(user);
    final o = outputs[call++];
    if (o is Exception) throw o;
    return o as String;
  }
}

ScoreDocument _doc() => ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(instrument: 'piano', staffCount: 2, measures: [
          ScoreMeasure(number: 1, voices: [
            ScoreVoice(staff: 1, voiceNo: 1, events: [
              ScoreEvent(
                  type: 'note',
                  dur: const Rational(2, 1),
                  pitches: [ScorePitch(step: 'C', octave: 4)]),
              ScoreEvent(
                  type: 'note',
                  dur: const Rational(2, 1),
                  pitches: [ScorePitch(step: 'E', octave: 4)]),
            ]),
            ScoreVoice(staff: 2, voiceNo: 1, events: [
              ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
            ]),
          ]),
        ]),
      ],
    );

PageSliceSpec _spec({bool boundary = false}) => PageSliceSpec(page: 1)
  ..measures.add(MeasureSliceSpec(measureIndex: 0, boundary: boundary));

/// LLM 输出 fragment JSON（小节 1，staff1 两音符可自定义音高）。
String _fragmentJson(String step1, String step2) => jsonEncode({
      'page': 1,
      'title': 'T',
      'measures': [
        {
          'number': 1,
          'voices': [
            {
              'staff': 1,
              'events': [
                {
                  'type': 'note',
                  'dur': {'n': 2, 'd': 1},
                  'pitches': [
                    {'step': step1, 'alter': 0, 'octave': 4}
                  ]
                },
                {
                  'type': 'note',
                  'dur': {'n': 2, 'd': 1},
                  'pitches': [
                    {'step': step2, 'alter': 0, 'octave': 4}
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

CorrectionPipeline _pipeline(FakeGateway gateway) => CorrectionPipeline(
      gateway: gateway,
      readImage: (_) async => Uint8List.fromList([1, 2, 3]),
      compress: (b) => b,
    );

void main() {
  test('发现错音 → modifyEvent 改动，原文档不被修改', () async {
    final doc = _doc();
    final snapshot = jsonEncode(doc.toJson());
    final gateway = FakeGateway([_fragmentJson('C', 'G')]); // E4 → G4
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      doc: doc,
      slices: [_spec()],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );

    expect(result.pages.single.ok, isTrue);
    expect(result.pages.single.unchanged, isFalse);
    expect(result.changes.length, 1);
    expect(result.changes.single.eventIndex, 1);
    expect(result.changes.single.after, contains('G4'));
    expect(jsonEncode(doc.toJson()), snapshot, reason: '原文档必须保持不变');
  });

  test('LLM 返回与现谱一致 → unchanged、无改动', () async {
    final gateway = FakeGateway([_fragmentJson('C', 'E')]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      doc: _doc(),
      slices: [_spec()],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.pages.single.unchanged, isTrue);
    expect(result.changes, isEmpty);
  });

  test('坏 JSON → 重试后成功，attempts=2', () async {
    final gateway = FakeGateway(['这不是 JSON', _fragmentJson('C', 'G')]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      doc: _doc(),
      slices: [_spec()],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.pages.single.ok, isTrue);
    expect(result.pages.single.attempts, 2);
  });

  test('小节数不符 → 回喂错误重试，第二次请求带反馈', () async {
    final extra = jsonDecode(_fragmentJson('C', 'E')) as Map<String, dynamic>;
    final extraMeasure = jsonDecode(jsonEncode(extra['measures'][0]))
        as Map<String, dynamic>;
    (extra['measures'] as List).add(extraMeasure); // 2 个小节 ≠ 1
    final gateway = FakeGateway([
      jsonEncode(extra),
      _fragmentJson('C', 'G'),
    ]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      doc: _doc(),
      slices: [_spec()],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.pages.single.ok, isTrue);
    expect(gateway.users.length, 2);
    expect(gateway.users[1], contains('相同数量的小节'));
  });

  test('3 次全部失败 → 页 failed、无改动', () async {
    final gateway = FakeGateway(['{"broken', '{"broken', '{"broken']);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      doc: _doc(),
      slices: [_spec()],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.pages.single.ok, isFalse);
    expect(result.pages.single.error, isNotNull);
    expect(result.changes, isEmpty);
  });

  test('跨页守卫：LLM 改写未拥有区间 → 改动丢弃 + 告警', () async {
    final doc = _doc();
    final spec = _spec(boundary: true)
      ..measures.single.ownedRanges['1:1'] = [(1, 2)]; // 只拥有第 2 个事件
    final gateway = FakeGateway([_fragmentJson('D', 'G')]); // 两个都改了
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      doc: doc,
      slices: [spec],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.pages.single.ok, isTrue);
    expect(result.changes, isEmpty, reason: '跨界改动小节整段丢弃');
    expect(result.warnings.join(), contains('跨页'));
  });

  test('跨页守卫：只改拥有区间 → 正常产出改动', () async {
    final spec = _spec(boundary: true)
      ..measures.single.ownedRanges['1:1'] = [(1, 2)];
    final gateway = FakeGateway([_fragmentJson('C', 'G')]); // 只改第 2 个
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      doc: _doc(),
      slices: [spec],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.changes.length, 1);
    expect(result.changes.single.eventIndex, 1);
    expect(result.warnings, isEmpty);
  });

  test('切片请求携带原图与切片 JSON，carry-in 上下文注入', () async {
    final doc = _doc();
    doc.parts.first.measures.insert(
      0,
      ScoreMeasure(number: 1, voices: [
        ScoreVoice(staff: 1, voiceNo: 1, events: [
          ScoreEvent(
              type: 'note',
              dur: const Rational(4, 1),
              pitches: [ScorePitch(step: 'B', octave: 3)]),
        ]),
      ]),
    );
    doc.parts.first.measures[1].number = 2;
    // 切片只含第 2 个小节（下标 1）→ 请求应带第 1 小节作 carry-in
    final spec = PageSliceSpec(page: 1)
      ..measures.add(MeasureSliceSpec(measureIndex: 1));
    final gateway = FakeGateway([_fragmentJson('C', 'E')]);
    await _pipeline(gateway).run(
      kind: 'piano',
      doc: doc,
      slices: [spec],
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(gateway.users.single, contains('仅供上下文参考'));
    expect(gateway.users.single, contains('"number":1'));
  });
}
