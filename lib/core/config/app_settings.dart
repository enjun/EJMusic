import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';

/// LLM 供应商配置（OpenAI 兼容协议）。
class LlmConfig {
  const LlmConfig({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  factory LlmConfig.defaults() => const LlmConfig(
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        model: 'qwen-vl-max',
        apiKey: '',
      );

  final String baseUrl;
  final String model;
  final String apiKey;

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;

  LlmConfig copyWith({String? baseUrl, String? model, String? apiKey}) =>
      LlmConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
      );

  Map<String, String> toPlainMap() => {'baseUrl': baseUrl, 'model': model};
}

/// 曲谱数据目录等全局设置。
class AppPreferences {
  AppPreferences({required this.lastImportDir});
  final String lastImportDir;

  Map<String, String> toPlainMap() => {'lastImportDir': lastImportDir};
}

const _keyBaseUrl = 'llm.baseUrl';
const _keyModel = 'llm.model';
const _keyApiKey = 'llm.apiKey';
const _keyCorrBaseUrl = 'llm.correction.baseUrl';
const _keyCorrModel = 'llm.correction.model';
const _keyCorrApiKey = 'llm.correction.apiKey';
const _keyLastImportDir = 'import.lastDir';

const _secureStorage = FlutterSecureStorage();

/// 加载 LLM 配置（baseUrl/model 存 SharedPreferences，apiKey 存安全存储）。
Future<LlmConfig> loadLlmConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final apiKey = await _secureStorage.read(key: _keyApiKey) ?? '';
  final def = LlmConfig.defaults();
  return LlmConfig(
    baseUrl: prefs.getString(_keyBaseUrl) ?? def.baseUrl,
    model: prefs.getString(_keyModel) ?? def.model,
    apiKey: apiKey,
  );
}

Future<void> saveLlmConfig(LlmConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyBaseUrl, config.baseUrl);
  await prefs.setString(_keyModel, config.model);
  if (config.apiKey.isEmpty) {
    await _secureStorage.delete(key: _keyApiKey);
  } else {
    await _secureStorage.write(key: _keyApiKey, value: config.apiKey);
  }
}

/// 纠错模型覆盖配置（可选，三项全空 = 跟随制谱模型，返回 null）。
Future<LlmConfig?> loadCorrectionConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final baseUrl = prefs.getString(_keyCorrBaseUrl) ?? '';
  final model = prefs.getString(_keyCorrModel) ?? '';
  final apiKey = await _secureStorage.read(key: _keyCorrApiKey) ?? '';
  if (baseUrl.isEmpty || model.isEmpty || apiKey.isEmpty) return null;
  return LlmConfig(baseUrl: baseUrl, model: model, apiKey: apiKey);
}

Future<void> saveCorrectionConfig(LlmConfig? config) async {
  final prefs = await SharedPreferences.getInstance();
  if (config == null || !config.isConfigured) {
    await prefs.remove(_keyCorrBaseUrl);
    await prefs.remove(_keyCorrModel);
    await _secureStorage.delete(key: _keyCorrApiKey);
    return;
  }
  await prefs.setString(_keyCorrBaseUrl, config.baseUrl);
  await prefs.setString(_keyCorrModel, config.model);
  await _secureStorage.write(key: _keyCorrApiKey, value: config.apiKey);
}

Future<String> loadLastImportDir() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyLastImportDir) ?? '';
}

Future<void> saveLastImportDir(String dir) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyLastImportDir, dir);
}

/// 应用级 providers。
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('在 main 中 override'),
);

final llmConfigProvider =
    AsyncNotifierProvider<LlmConfigNotifier, LlmConfig>(LlmConfigNotifier.new);

class LlmConfigNotifier extends AsyncNotifier<LlmConfig> {
  @override
  Future<LlmConfig> build() => loadLlmConfig();

  Future<void> save(LlmConfig config) async {
    await saveLlmConfig(config);
    state = AsyncData(config);
  }
}
