import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/correction_controller.dart';
import '../logic/correction_pipeline.dart' show CorrectionPageProgress;
import 'change_review_list.dart';

/// AI 纠错页：stage1 逐页对照原图校对（进度 + 单页重试），
/// stage2 修改清单确认后应用。
class CorrectionPage extends ConsumerStatefulWidget {
  const CorrectionPage({super.key, required this.songId});

  final int songId;

  @override
  ConsumerState<CorrectionPage> createState() => _CorrectionPageState();
}

class _CorrectionPageState extends ConsumerState<CorrectionPage> {
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(correctionControllerProvider(widget.songId).notifier).start());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(correctionControllerProvider(widget.songId));
    final controller = ref.read(correctionControllerProvider(widget.songId).notifier);

    // 应用完成后提示并返回
    final msg = state.resultMessage;
    if (msg != null && state.stage == CorrectionStage.idle && !_notified) {
      _notified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.of(context).pop();
      });
    }

    return PopScope(
      canPop: state.stage != CorrectionStage.running,
      child: Scaffold(
        appBar: AppBar(title: const Text('AI 纠错')),
        body: _buildBody(context, state, controller),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, CorrectionState state, CorrectionController controller) {
    if (state.stage == CorrectionStage.idle && state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.start,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.stage == CorrectionStage.review) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('AI 对照原图发现以下修改，请确认后应用：',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          Expanded(
            child: ChangeReviewList(
              changes: state.changes,
              warnings: state.warnings,
              onToggle: controller.toggle,
              onSetAll: controller.setAll,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: state.applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, size: 18),
                  label: Text(state.applying
                      ? '应用中…'
                      : '应用选中（${state.selectedCount} 处）'),
                  onPressed: state.applying || state.selectedCount == 0
                      ? null
                      : controller.applySelected,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // running（或初始）
    final done = state.pages
        .where((p) => p.status == 'ok' || p.status == 'unchanged' || p.status == 'failed')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('正在逐页盲识别原图并与当前曲谱比对…',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.pages.isEmpty ? null : done / state.pages.length,
              ),
              const SizedBox(height: 4),
              Text('${done} / ${state.pages.length} 页',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final p in state.pages) _pageTile(context, p, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageTile(BuildContext context, CorrectionPageProgress p,
      CorrectionController controller) {
    final (icon, color, label) = switch (p.status) {
      'ok' => (
          Icons.check_circle,
          Colors.green,
          '发现 ${p.changeCount} 处修改'
              '${p.largeDiff ? '（改动较多，请仔细核对）' : ''}'
              '（第${p.attempts}次尝试）'
        ),
      'unchanged' => (Icons.check_circle_outline, Colors.grey, '无修改'),
      'failed' => (Icons.error, Colors.red, p.error ?? '失败'),
      'running' => (Icons.sync, Colors.blue, '第${p.attempts}次盲识别中…'),
      _ => (Icons.schedule, Colors.grey, '等待中'),
    };
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text('第 ${p.pageIndex} 页'),
      subtitle: Text(label, style: const TextStyle(fontSize: 12)),
      trailing: p.status == 'failed' && p.pageIndex > 0
          ? TextButton(
              onPressed: () => controller.retryPage(p.pageIndex),
              child: const Text('重试本页'),
            )
          : null,
    );
  }
}
