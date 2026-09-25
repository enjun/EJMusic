import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/app_settings.dart';

/// LLM 抽象（便于 mock 回放测试与更换 provider）。
abstract class LlmGateway {
  /// 返回模型输出的原始文本（应包含 JSON）。
  Future<String> completeJson({
    required String system,
    required String user,
    required List<String> imageJpegBase64,
  });
}

/// OpenAI 兼容 /chat/completions 客户端（国内大模型通协议）。
/// 429/5xx/超时自动指数退避重试。
class DioLlmClient implements LlmGateway {
  DioLlmClient({
    Dio? dio,
    required this._loadConfig,
    Future<void> Function(Duration delay)? sleep,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 180),
              // 网关错误可能返回 HTML/纯文本，手动 JSON 解析以免 dio 内部抛解析异常
              responseType: ResponseType.plain,
            )),
        _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  final Dio _dio;
  final LlmConfig Function() _loadConfig;
  final Future<void> Function(Duration) _sleep;

  @override
  Future<String> completeJson({
    required String system,
    required String user,
    required List<String> imageJpegBase64,
  }) async {
    final config = _loadConfig();
    if (!config.isConfigured) {
      throw LlmConfigException('未配置大模型 API（base_url / api_key / model）');
    }
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': user},
      for (final b64 in imageJpegBase64)
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$b64'},
        },
    ];
    final body = <String, dynamic>{
      'model': config.model,
      'temperature': 0.1,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': content},
      ],
    };

    const maxAttempts = 4;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await _dio.post<String>(
          '${config.baseUrl}/chat/completions',
          options: Options(headers: {
            'Authorization': 'Bearer ${config.apiKey}',
          }),
          data: body,
        );
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
        return extractContent(data);
      } on DioException catch (e) {
        lastError = e;
        final status = e.response?.statusCode ?? 0;
        final retryable = status == 429 ||
            status >= 500 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (!retryable || attempt == maxAttempts) rethrow;
        // 指数退避：2s, 4s, 8s
        await _sleep(Duration(seconds: 1 << attempt));
      }
    }
    throw LlmRequestException('请求失败：$lastError');
  }

  /// 解析 choices[0].message.content；兼容 content 为分段数组的返回。
  static String extractContent(Map<String, dynamic> data) {
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const FormatException('响应缺少 choices');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    if (message == null) throw const FormatException('响应缺少 message');
    final content = message['content'];
    if (content is String) return content;
    if (content is List) {
      final sb = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) sb.write(part['text']);
      }
      return sb.toString();
    }
    throw const FormatException('响应 content 类型异常');
  }

  /// 从模型输出中提取 JSON（剥 markdown 围栏、前后杂质）。
  static String extractJson(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      final end = s.lastIndexOf('```');
      if (end >= 0) s = s.substring(0, end);
      s = s.trim();
    }
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('输出中不包含 JSON 对象');
    }
    return s.substring(start, end + 1);
  }
}

class LlmConfigException implements Exception {
  LlmConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LlmRequestException implements Exception {
  LlmRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}
