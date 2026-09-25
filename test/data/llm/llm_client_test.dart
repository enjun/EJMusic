import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ejmusic/core/config/app_settings.dart';
import 'package:ejmusic/data/llm/llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// 按请求序号返回脚本化响应的 mock 适配器。
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.responses);

  /// 每次请求依次消费；null → 抛 429。
  final List<ResponseBody?> responses;
  final List<Map<String, dynamic>> requests = [];
  int call = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final i = call++;
    requests.add({
      'url': options.uri.toString(),
      'headers': options.headers,
      'body': options.data,
    });
    final r = responses[i];
    if (r == null) {
      return ResponseBody.fromString('rate limited', 429, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    return r;
  }
}

LlmConfig _config() => const LlmConfig(
      baseUrl: 'https://llm.example.com/v1',
      model: 'qwen-vl-max',
      apiKey: 'sk-test',
    );

ResponseBody _okContent(Map<String, dynamic> content) => ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': jsonEncode(content)}
          }
        ]
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  test('请求体：模型/温度/json_object/图片 data URL', () async {
    final adapter = ScriptedAdapter([_okContent({'ok': 1})]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = DioLlmClient(dio: dio, loadConfig: _config);

    await client.completeJson(
      system: 'sys',
      user: 'usr',
      imageJpegBase64: ['QUJD'], // base64("ABC")
    );

    final req = adapter.requests.single;
    expect(req['url'], 'https://llm.example.com/v1/chat/completions');
    expect(req['headers']['Authorization'], 'Bearer sk-test');
    final body = req['body'] as Map<String, dynamic>;
    expect(body['model'], 'qwen-vl-max');
    expect(body['temperature'], 0.1);
    expect((body['response_format'] as Map)['type'], 'json_object');
    final messages = body['messages'] as List;
    expect(messages[0]['role'], 'system');
    final userContent = messages[1]['content'] as List;
    expect(userContent[0]['type'], 'text');
    expect(userContent[1]['type'], 'image_url');
    expect((userContent[1]['image_url'] as Map)['url'],
        'data:image/jpeg;base64,QUJD');
  });

  test('429 自动重试后成功（指数退避）', () async {
    final adapter = ScriptedAdapter([null, null, _okContent({'ok': 1})]);
    final dio = Dio()..httpClientAdapter = adapter;
    final delays = <Duration>[];
    final client = DioLlmClient(
      dio: dio,
      loadConfig: _config,
      sleep: (d) async => delays.add(d),
    );

    final out = await client.completeJson(system: 's', user: 'u', imageJpegBase64: []);
    expect(out, '{"ok":1}');
    expect(delays, [const Duration(seconds: 2), const Duration(seconds: 4)]);
  });

  test('连续 429 超过上限抛异常', () async {
    final adapter = ScriptedAdapter([null, null, null, null]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = DioLlmClient(
      dio: dio,
      loadConfig: _config,
      sleep: (_) async {},
    );
    await expectLater(
      client.completeJson(system: 's', user: 'u', imageJpegBase64: []),
      throwsA(isA<DioException>()),
    );
  });

  test('未配置 API 抛 LlmConfigException', () async {
    final adapter = ScriptedAdapter([]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = DioLlmClient(
      dio: dio,
      loadConfig: () => const LlmConfig(baseUrl: '', model: '', apiKey: ''),
    );
    await expectLater(
      client.completeJson(system: 's', user: 'u', imageJpegBase64: []),
      throwsA(isA<LlmConfigException>()),
    );
  });

  test('extractContent 兼容分段 content', () {
    final data = {
      'choices': [
        {
          'message': {
            'content': [
              {'type': 'text', 'text': 'hello '},
              {'type': 'text', 'text': 'world'},
            ]
          }
        }
      ]
    };
    expect(DioLlmClient.extractContent(data), 'hello world');
  });

  test('extractContent 透出网关错误包（余额/额度类 429 带 200 包）', () {
    final data = {
      'error': {'code': '1113', 'message': '余额不足或无可用资源包,请充值。'}
    };
    expect(
      () => DioLlmClient.extractContent(data),
      throwsA(isA<FormatException>().having(
        (e) => e.message,
        'message',
        'API 错误 1113：余额不足或无可用资源包,请充值。',
      )),
    );
  });

  test('extractJson 剥 markdown 围栏与前后杂质', () {
    expect(DioLlmClient.extractJson('```json\n{"a":1}\n```'), '{"a":1}');
    expect(DioLlmClient.extractJson('好的，结果如下：{"a": {"b": 2}} 请查收'),
        '{"a": {"b": 2}}');
    expect(() => DioLlmClient.extractJson('没有 json'), throwsFormatException);
  });
}
