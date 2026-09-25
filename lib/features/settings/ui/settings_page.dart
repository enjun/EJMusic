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
  bool _obscureKey = true;
  bool _loaded = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _fillFrom(LlmConfig config) {
    _baseUrl.text = config.baseUrl;
    _model.text = config.model;
    _apiKey.text = config.apiKey;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(llmConfigProvider);
    configAsync.whenData((c) {
      if (!_loaded) _fillFrom(c);
    });

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
      Navigator.of(context).pop();
    }
  }
}
