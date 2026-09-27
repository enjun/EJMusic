import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';

/// 常见国内大模型的快捷预设（OpenAI 兼容端点）。
const _presets = <String, (String, String)>{
  '通义千问': ('https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-vl-max'),
  '智谱 GLM': ('https://open.bigmodel.cn/api/paas/v4', 'glm-4v-plus'),
  '豆包': ('https://ark.cn-beijing.volces.com/api/v3', 'doubao-1.5-vision-pro'),
  'Kimi': ('https://api.moonshot.cn/v1', 'moonshot-v1-8k-vision-preview'),
};

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  // 纠错专用模型（可选，留空跟随制谱模型）
  final _corrBaseUrl = TextEditingController();
  final _corrModel = TextEditingController();
  final _corrApiKey = TextEditingController();
  bool _corrExpanded = false;
  bool _obscureKey = true;
  bool _obscureCorrKey = true;
  bool _loaded = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _corrBaseUrl.dispose();
    _corrModel.dispose();
    _corrApiKey.dispose();
    super.dispose();
  }

  Future<void> _fillFrom(LlmConfig config) async {
    _baseUrl.text = config.baseUrl;
    _model.text = config.model;
    _apiKey.text = config.apiKey;
    final corr = await loadCorrectionConfig();
    if (corr != null) {
      _corrBaseUrl.text = corr.baseUrl;
      _corrModel.text = corr.model;
      _corrApiKey.text = corr.apiKey;
      _corrExpanded = true;
    }
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(llmConfigProvider);
    if (configAsync.value != null && !_loaded) {
      _fillFrom(configAsync.value!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: configAsync.isLoading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('配置加载失败：$e')),
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('大模型服务（OpenAI 兼容协议）',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('用于把扫描图片制作为可交互曲谱。API Key 仅保存在本机安全存储。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _presets.entries)
                  ActionChip(
                    label: Text(entry.key),
                    onPressed: () {
                      setState(() {
                        _baseUrl.text = entry.value.$1;
                        _model.text = entry.value.$2;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrl,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              decoration: const InputDecoration(
                labelText: '模型名称',
                hintText: 'qwen-vl-max',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKey,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _corrExpanded,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('纠错专用模型（可选）',
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                  '留空跟随制谱模型；可填更强的视觉模型提升 AI 纠错准确率',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in _presets.entries)
                        ActionChip(
                          label: Text(entry.key),
                          onPressed: () {
                            setState(() {
                              _corrBaseUrl.text = entry.value.$1;
                              _corrModel.text = entry.value.$2;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _corrBaseUrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _corrModel,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _corrApiKey,
                    obscureText: _obscureCorrKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCorrKey
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureCorrKey = !_obscureCorrKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存配置'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final controller = ref.read(llmConfigProvider.notifier);
    final current = ref.read(llmConfigProvider).value ?? LlmConfig.defaults();
    await controller.save(current.copyWith(
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      apiKey: _apiKey.text.trim(),
    ));
    // 纠错模型三件套任一非空才视为配置
    final corrBase = _corrBaseUrl.text.trim();
    final corrModel = _corrModel.text.trim();
    final corrKey = _corrApiKey.text.trim();
    await saveCorrectionConfig(
      (corrBase.isEmpty && corrModel.isEmpty && corrKey.isEmpty)
          ? null
          : LlmConfig(
              baseUrl: corrBase,
              model: corrModel,
              apiKey: corrKey,
            ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
      Navigator.of(context).pop();
    }
  }
}
