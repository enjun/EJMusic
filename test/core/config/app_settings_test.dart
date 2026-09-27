import 'package:ejmusic/core/config/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage 无单元测试实现，用内存 map mock 其 method channel
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStore = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    final args = call.arguments as Map?;
    switch (call.method) {
      case 'read':
        return secureStore[args!['key'] as String];
      case 'write':
        secureStore[args!['key'] as String] = args['value'] as String;
        return null;
      case 'delete':
        secureStore.remove(args!['key'] as String);
        return null;
      default:
        return null;
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStore.clear();
  });

  test('loadCorrectionConfig：未配置返回 null', () async {
    expect(await loadCorrectionConfig(), isNull);
  });

  test('saveCorrectionConfig：存取往返', () async {
    await saveCorrectionConfig(const LlmConfig(
      baseUrl: 'https://example.com/v1',
      model: 'qwen-vl-max',
      apiKey: 'sk-test',
    ));
    final c = await loadCorrectionConfig();
    expect(c, isNotNull);
    expect(c!.baseUrl, 'https://example.com/v1');
    expect(c.model, 'qwen-vl-max');
    expect(c.apiKey, 'sk-test');
  });

  test('saveCorrectionConfig：传 null 清除配置', () async {
    await saveCorrectionConfig(const LlmConfig(
      baseUrl: 'https://example.com/v1',
      model: 'qwen-vl-max',
      apiKey: 'sk-test',
    ));
    await saveCorrectionConfig(null);
    expect(await loadCorrectionConfig(), isNull);
  });

  test('saveCorrectionConfig：任一字段缺失视为未配置', () async {
    await saveCorrectionConfig(const LlmConfig(
      baseUrl: 'https://example.com/v1',
      model: '',
      apiKey: 'sk-test',
    ));
    expect(await loadCorrectionConfig(), isNull);
  });
}
