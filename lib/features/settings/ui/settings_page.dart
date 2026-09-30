import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/ui/app_theme.dart';

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

    final margin = AppSpacing.pageMargin(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: TextButton(
              onPressed: configAsync.isLoading ? null : _save,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('配置加载失败：$e')),
        data: (_) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: SizedBox(
              width: double.infinity,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  margin,
                  AppSpacing.xs,
                  margin,
                  AppSpacing.xxl,
                ),
                children: [
                  const _SectionCard(
                    icon: Icons.palette_outlined,
                    title: '界面外观',
                    description: '深色模式适合夜间制谱与演奏。',
                    child: _ThemeModeSelector(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    icon: Icons.smart_toy_outlined,
                    title: '大模型服务',
                    description:
                        'OpenAI 兼容协议。用于把扫描图片制作为可交互曲谱；'
                        'API Key 仅保存在本机安全存储。',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final entry in _presets.entries)
                              ActionChip(
                                avatar: const Icon(Icons.bolt, size: 15),
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
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _baseUrl,
                          decoration: const InputDecoration(
                            labelText: 'Base URL',
                            hintText: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
                            prefixIcon: Icon(Icons.link, size: 20),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _model,
                          decoration: const InputDecoration(
                            labelText: '模型名称',
                            hintText: 'qwen-vl-max',
                            prefixIcon: Icon(Icons.memory_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _apiKey,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            prefixIcon: const Icon(
                              Icons.key_outlined,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscureKey ? '显示' : '隐藏',
                              icon: Icon(
                                _obscureKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureKey = !_obscureKey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    icon: Icons.auto_fix_high_outlined,
                    title: '纠错专用模型（可选）',
                    description: '留空跟随制谱模型；可填更强的视觉模型提升 AI 纠错准确率。',
                    trailing: Icon(
                      _corrExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTapHeader: () =>
                        setState(() => _corrExpanded = !_corrExpanded),
                    child: !_corrExpanded
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  for (final entry in _presets.entries)
                                    ActionChip(
                                      avatar: const Icon(Icons.bolt, size: 15),
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
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: _corrBaseUrl,
                                decoration: const InputDecoration(
                                  labelText: 'Base URL',
                                  prefixIcon: Icon(Icons.link, size: 20),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: _corrModel,
                                decoration: const InputDecoration(
                                  labelText: '模型名称',
                                  prefixIcon: Icon(
                                    Icons.memory_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: _corrApiKey,
                                obscureText: _obscureCorrKey,
                                decoration: InputDecoration(
                                  labelText: 'API Key',
                                  prefixIcon: const Icon(
                                    Icons.key_outlined,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureCorrKey ? '显示' : '隐藏',
                                    icon: Icon(
                                      _obscureCorrKey
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureCorrKey = !_obscureCorrKey,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text('保存配置'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final controller = ref.read(llmConfigProvider.notifier);
    final current = ref.read(llmConfigProvider).value ?? LlmConfig.defaults();
    await controller.save(
      current.copyWith(
        baseUrl: _baseUrl.text.trim(),
        model: _model.text.trim(),
        apiKey: _apiKey.text.trim(),
      ),
    );
    // 纠错模型三件套任一非空才视为配置
    final corrBase = _corrBaseUrl.text.trim();
    final corrModel = _corrModel.text.trim();
    final corrKey = _corrApiKey.text.trim();
    await saveCorrectionConfig(
      (corrBase.isEmpty && corrModel.isEmpty && corrKey.isEmpty)
          ? null
          : LlmConfig(baseUrl: corrBase, model: corrModel, apiKey: corrKey),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop();
    }
  }
}

/// 主题模式选择：跟随系统 / 浅色 / 深色。
class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined, size: 18),
          label: Text('跟随系统'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 18),
          label: Text('浅色'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 18),
          label: Text('深色'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) =>
          ref.read(themeModeProvider.notifier).set(s.first),
    );
  }
}

/// 设置分区卡片：图标 + 标题 + 说明 + 内容；[onTapHeader] 非空时标题可点。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.description,
    this.child,
    this.trailing,
    this.onTapHeader,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? child;
  final Widget? trailing;
  final VoidCallback? onTapHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final header = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (description != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(description!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onTapHeader != null)
            InkWell(
              onTap: onTapHeader,
              borderRadius: AppRadius.lgAll,
              child: header,
            )
          else
            header,
          if (child != null) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: child!,
            ),
          ],
        ],
      ),
    );
  }
}
