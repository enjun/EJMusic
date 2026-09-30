import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/components.dart';
import '../../../data/render/sheet_webview.dart';
import '../../../domain/score/convert/split_volume.dart';
import '../../../domain/score/convert/to_musicxml.dart';
import '../../generation/logic/generation_controller.dart';
import '../../library/library_providers.dart';

final _sheetControllerProvider = Provider.autoDispose<SheetWebviewController>((
  ref,
) {
  final c = SheetWebviewController();
  ref.onDispose(c.dispose);
  return c;
});

/// 曲谱查看器：WebView 内嵌 osmd-extended 渲染 MusicXML；长曲自动分册。
class ViewerPage extends ConsumerStatefulWidget {
  const ViewerPage({super.key, required this.songId});

  final int songId;

  @override
  ConsumerState<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends ConsumerState<ViewerPage> {
  double _zoom = 1.0;
  String? _error;
  int? _totalSteps;

  List<ScoreVolume>? _volumes;
  int _volumeIndex = 0;
  final _volumeXml = <int, String>{};
  Future<String>? _htmlFuture;

  @override
  void initState() {
    super.initState();
    _loadDoc();
  }

  Future<void> _loadDoc() async {
    try {
      final store = await ref.read(scoreStoreProvider.future);
      final doc = await store.load(widget.songId);
      if (doc == null) throw Exception('曲谱尚未制作完成，请先完成「制作曲谱」');
      final vols = splitIntoVolumes(doc);
      if (!mounted) return;
      setState(() => _volumes = vols);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
        );
      }
    }
  }

  String _xmlFor(int index) {
    return _volumeXml.putIfAbsent(
      index,
      () => scoreToMusicXml(_volumes![index].document),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songProvider(widget.songId));
    final controller = ref.watch(_sheetControllerProvider);
    final song = songAsync.value;

    final volumes = _volumes;
    final total = volumes?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(song?.title ?? '曲谱'),
        actions: [
          if (total > 1) ...[
            IconButton(
              tooltip: '上一册',
              icon: const Icon(Icons.navigate_before),
              onPressed: _volumeIndex > 0
                  ? () => _switchVolume(controller, _volumeIndex - 1)
                  : null,
            ),
            _BarChip(label: '第 ${_volumeIndex + 1}/$total 册'),
            IconButton(
              tooltip: '下一册',
              icon: const Icon(Icons.navigate_next),
              onPressed: _volumeIndex < total - 1
                  ? () => _switchVolume(controller, _volumeIndex + 1)
                  : null,
            ),
            const _BarDivider(),
          ],
          const _BarDivider(),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: '缩小',
            onPressed: () => _adjustZoom(controller, -0.1),
          ),
          _BarChip(label: '${(_zoom * 100).round()}%'),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: '放大',
            onPressed: () => _adjustZoom(controller, 0.1),
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: '光标回到开头',
            onPressed: () => controller.cursorReset(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _error != null
          ? EmptyHint(
              icon: Icons.error_outline,
              title: '无法显示曲谱',
              message: _error,
            )
          : volumes == null
          ? const Center(child: CircularProgressIndicator())
          : _buildWebView(controller, SheetThemeColors.of(Theme.of(context))),
    );
  }

  Widget _buildWebView(
    SheetWebviewController controller,
    SheetThemeColors sheetTheme,
  ) {
    // 宿主页只加载一次；曲谱按册经 loadMusicXml 注入
    _htmlFuture ??= buildSheetHostHtml();
    return FutureBuilder<String>(
      future: _htmlFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final html = snap.data!;
        return Stack(
          children: [
            InAppWebView(
              initialData: InAppWebViewInitialData(
                data: html,
                mimeType: 'text/html',
                encoding: 'utf-8',
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: false,
                supportZoom: false,
                disableContextMenu: true,
              ),
              onWebViewCreated: (w) {
                controller.attach(w);
                w.addJavaScriptHandler(
                  handlerName: 'ejm',
                  callback: (args) {
                    if (args.isNotEmpty && args.first is Map) {
                      final event = SheetEvent.from(args.first as Map);
                      controller.handleEvent(event);
                      _onSheetEvent(event);
                    }
                    return null;
                  },
                );
              },
              onLoadStop: (_, _) async {
                await controller.pageReady;
                await controller.setThemeFrom(sheetTheme);
                await controller.setZoom(_zoom);
                await controller.loadMusicXml(_xmlFor(_volumeIndex));
              },
            ),
            if (_totalSteps != null)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: OverlayPill(
                  icon: Icons.timeline,
                  label: '光标步数 $_totalSteps',
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _switchVolume(
    SheetWebviewController controller,
    int index,
  ) async {
    if (_volumes == null || index < 0 || index >= _volumes!.length) return;
    setState(() {
      _volumeIndex = index;
      _totalSteps = null;
    });
    await controller.loadMusicXml(_xmlFor(index));
    await controller.setZoom(_zoom);
  }

  void _onSheetEvent(SheetEvent event) {
    if (!mounted) return;
    switch (event) {
      case SheetReady(:final totalSteps):
        setState(() => _totalSteps = totalSteps);
      case SheetError(:final message):
        setState(() => _error = '渲染失败：$message');
      default:
        break;
    }
  }

  Future<void> _adjustZoom(
    SheetWebviewController controller,
    double delta,
  ) async {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.5, 2.5);
    });
    await controller.setZoom(_zoom);
  }
}

/// AppBar 内的信息胶囊（册数 / 缩放）。
class _BarChip extends StatelessWidget {
  const _BarChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    child: SizedBox(
      height: 20,
      child: VerticalDivider(
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}
