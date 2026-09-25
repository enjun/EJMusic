import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/render/sheet_webview.dart';
import '../../../domain/score/convert/split_volume.dart';
import '../../../domain/score/convert/to_musicxml.dart';
import '../../generation/logic/generation_controller.dart';
import '../../library/library_providers.dart';

final _sheetControllerProvider = Provider.autoDispose<SheetWebviewController>((ref) {
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
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _xmlFor(int index) {
    return _volumeXml.putIfAbsent(
        index, () => scoreToMusicXml(_volumes![index].document));
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
            Center(
              child: Text('第 ${_volumeIndex + 1}/$total 册',
                  style: const TextStyle(fontSize: 14)),
            ),
            IconButton(
              tooltip: '下一册',
              icon: const Icon(Icons.navigate_next),
              onPressed: _volumeIndex < total - 1
                  ? () => _switchVolume(controller, _volumeIndex + 1)
                  : null,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: '缩小',
            onPressed: () => _adjustZoom(controller, -0.1),
          ),
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
        ],
      ),
      body: _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('渲染失败：$_error', textAlign: TextAlign.center),
            ))
          : volumes == null
              ? const Center(child: CircularProgressIndicator())
              : _buildWebView(controller),
    );
  }

  Widget _buildWebView(SheetWebviewController controller) {
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
                await controller.setZoom(_zoom);
                await controller.loadMusicXml(_xmlFor(_volumeIndex));
              },
            ),
            if (_totalSteps != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '光标步数 $_totalSteps',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _switchVolume(SheetWebviewController controller, int index) async {
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
        setState(() => _error = message);
      default:
        break;
    }
  }

  Future<void> _adjustZoom(SheetWebviewController controller, double delta) async {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.5, 2.5);
    });
    await controller.setZoom(_zoom);
  }
}
