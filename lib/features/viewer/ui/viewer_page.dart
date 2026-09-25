import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/render/sheet_webview.dart';
import '../../library/library_providers.dart';

final _sheetControllerProvider = Provider.autoDispose<SheetWebviewController>((ref) {
  final c = SheetWebviewController();
  ref.onDispose(c.dispose);
  return c;
});

/// 曲谱查看器：WebView 内嵌 osmd-extended 渲染 MusicXML。
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

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songProvider(widget.songId));
    final controller = ref.watch(_sheetControllerProvider);

    final song = songAsync.value;
    final xmlPath = song?.musicxmlCachePath;

    return Scaffold(
      appBar: AppBar(
        title: Text(song?.title ?? '曲谱'),
        actions: [
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
          : _buildWebView(controller, xmlPath),
    );
  }

  Widget _buildWebView(SheetWebviewController controller, String? xmlPath) {
    if (xmlPath == null || !File(xmlPath).existsSync()) {
      return const Center(child: Text('曲谱尚未制作完成，请先完成「制作曲谱」'));
    }
    // 宿主页与曲谱一并预载；WebView2 不支持 file:// initialFile，用 initialData 内联 JS
    final htmlFuture = buildSheetHostHtml();
    final xmlFuture = File(xmlPath).readAsString();
    return FutureBuilder<List<String>>(
      future: Future.wait([htmlFuture, xmlFuture]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final html = snap.data![0];
        final xml = snap.data![1];
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
                await controller.loadMusicXml(xml);
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
