import 'dart:convert';
import 'dart:typed_data';

import 'package:ejmusic/data/llm/llm_client.dart';
import 'package:ejmusic/features/generation/logic/generation_pipeline.dart';
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

const goodFragment = {
  'page': 1,
  'title': '小星星',
  'keyFifths': 0,
  'timeBeats': 4,
  'timeBeatType': 4,
  'bpm': 100,
  'pickup': false,
  'measures': [
    {
      'number': 1,
      'voices': [
        {
          'staff': 1,
          'events': [
            {
              'type': 'note',
              'dur': {'n': 1, 'd': 1},
              'pitches': [
                {'step': 'C', 'alter': 0, 'octave': 4}
              ]
            },
            {
              'type': 'note',
              'dur': {'n': 1, 'd': 1},
              'pitches': [
                {'step': 'E', 'alter': 0, 'octave': 4}
              ]
            },
            {
              'type': 'note',
              'dur': {'n': 1, 'd': 1},
              'pitches': [
                {'step': 'G', 'alter': 0, 'octave': 4}
              ]
            },
            {
              'type': 'note',
              'dur': {'n': 1, 'd': 1},
              'pitches': [
                {'step': 'C', 'alter': 0, 'octave': 5}
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
};

Map<String, dynamic> pageN(int n) {
  final json = jsonDecode(jsonEncode(goodFragment)) as Map<String, dynamic>;
  json['page'] = n;
  return json;
}

GenerationPipeline _pipeline(FakeGateway gateway) => GenerationPipeline(
      gateway: gateway,
      readImage: (_) async => Uint8List.fromList([1, 2, 3]),
      compress: (b) => b, // 测试跳过真实压缩
    );

void main() {
  test('单页成功：解析 + 校验 + 进度回调', () async {
    final gateway = FakeGateway([
      '```json\n${jsonEncode(pageN(1))}\n```',
    ]);
    final progressLog = <String>[];
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      pages: [PageInput(pageIndex: 1, imagePath: '/img/1.jpg')],
      onProgress: (p) => progressLog.add('${p.pageIndex}:${p.status}'),
    );

    expect(result.allOk, isTrue);
    expect(gateway.users.single.contains('第 1 页'), isTrue);
    expect(progressLog, contains('1:ok'));
    final doc = result.document!;
    expect(doc.meta.title, '小星星');
    expect(doc.meta.bpm, 100);
    expect(doc.parts.first.measures.length, 1);
    expect(doc.parts.first.measures.first.voices.first.events.length, 4);
  });

  test('超拍错误回喂重试后成功', () async {
    // 第一次：5 拍（超拍）→ 校验失败 → 第二次：正确 4 拍
    final bad = jsonDecode(jsonEncode(pageN(1))) as Map<String, dynamic>;
    final badMeasure = bad['measures'][0] as Map<String, dynamic>;
    (badMeasure['voices'][0]['events'] as List).add({
      'type': 'note',
      'dur': {'n': 1, 'd': 1},
      'pitches': [
        {'step': 'D', 'alter': 0, 'octave': 4}
      ]
    });
    final gateway = FakeGateway([
      jsonEncode(bad),
      jsonEncode(pageN(1)),
    ]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      pages: [PageInput(pageIndex: 1, imagePath: '/img/1.jpg')],
    );

    expect(result.allOk, isTrue);
    expect(gateway.users.length, 2);
    // 第二次请求带错误反馈
    expect(gateway.users[1], contains('measure_overfull'));
    expect(gateway.users[1], contains('重新输出完整 JSON'));
  });

  test('坏 JSON 修复路径 + attempts 计数', () async {
    final gateway = FakeGateway([
      '这不是 JSON',
      jsonEncode(pageN(1)),
    ]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.allOk, isTrue);
    expect(result.pages.single.attempts, 2);
  });

  test('全部重试失败 → 页 failed、结果不含 document', () async {
    final gateway = FakeGateway([
      '{"broken', '{"broken', '{"broken',
    ]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.allOk, isFalse);
    expect(result.document, isNull);
    expect(result.pages.single.error, isNotNull);
  });

  test('两页合并 + carry-in 上下文注入', () async {
    final gateway = FakeGateway([
      jsonEncode(pageN(1)),
      jsonEncode(pageN(2)),
    ]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      pages: [
        PageInput(pageIndex: 1, imagePath: '/1.jpg'),
        PageInput(pageIndex: 2, imagePath: '/2.jpg'),
      ],
    );

    expect(result.allOk, isTrue);
    // 第 2 页请求包含第 1 页末尾小节 JSON
    expect(gateway.users[1], contains('上一页最后的小节 JSON'));
    expect(gateway.users[1], contains('"number":1'));
    // 合并后 2 个小节，重编号正确
    expect(result.document!.parts.first.measures.length, 2);
    expect(result.document!.meta.pageCount, 2);
  });

  test('单页失败其余成功 → 部分成功仍合并', () async {
    final gateway = FakeGateway([
      jsonEncode(pageN(1)),
      '{"x', '{"x', '{"x',
    ]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      pages: [
        PageInput(pageIndex: 1, imagePath: '/1.jpg'),
        PageInput(pageIndex: 2, imagePath: '/2.jpg'),
      ],
    );
    expect(result.allOk, isFalse);
    expect(result.pages[0].ok, isTrue);
    expect(result.pages[1].ok, isFalse);
    expect(result.document, isNotNull);
    expect(result.document!.parts.first.measures.length, 1);
  });

  test('欠拍自动补休止（不触发重试）', () async {
    final underfull = jsonDecode(jsonEncode(pageN(1))) as Map<String, dynamic>;
    final measure = underfull['measures'][0] as Map<String, dynamic>;
    (measure['voices'][0]['events'] as List).removeLast(); // 3 拍
    final gateway = FakeGateway([jsonEncode(underfull)]);
    final result = await _pipeline(gateway).run(
      kind: 'piano',
      pages: [PageInput(pageIndex: 1, imagePath: '/1.jpg')],
    );
    expect(result.allOk, isTrue);
    expect(result.mergeWarnings.join(), contains('补休止'));
    expect(
      result.document!.parts.first.measures.first.voices.first.events.length,
      4,
    );
  });
}
