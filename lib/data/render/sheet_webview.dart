import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 宿主页 HTML：内联 osmd-extended bundle，避免 file:// / asset URL 兼容问题。
Future<String> buildSheetHostHtml() async {
  final html = await rootBundle.loadString('assets/web/sheet.html');
  final js = await rootBundle.load('assets/web/vendor/osmd-extended.min.js');
  final jsStr = String.fromCharCodes(js.buffer.asUint8List());
  return html.replaceFirst(
    '<script src="vendor/osmd-extended.min.js"></script>',
    '<script>$jsStr</script>',
  );
}

/// JS bridge 事件（JS → Dart）。
sealed class SheetEvent {
  const SheetEvent();

  static SheetEvent from(Map<dynamic, dynamic> m) {
    switch (m['event']) {
      case 'pageReady':
        return const SheetPageReady();
      case 'ready':
        final steps = <int, double>{
          for (final s in (m['stepsMap'] as List))
            (s['step'] as num).toInt(): (s['quarter'] as num).toDouble(),
        };
        final anchors = <int, int>{
          for (final s in (m['stepsMap'] as List))
            (s['step'] as num).toInt(): (s['m'] as num?)?.toInt() ?? -1,
        };
        return SheetReady(
          totalSteps: (m['totalSteps'] as num).toInt(),
          stepQuarters: steps,
          stepMeasures: anchors,
        );
      case 'noteClicked':
        return SheetNoteClicked(
          measure: (m['m'] as num).toInt(),
          staff: (m['s'] as num).toInt(),
          eventIndex: (m['k'] as num).toInt(),
        );
      case 'error':
        return SheetError(m['message']?.toString() ?? '未知渲染错误');
      default:
        return SheetUnknownEvent(m.toString());
    }
  }
}

class SheetPageReady extends SheetEvent {
  const SheetPageReady();
}

class SheetReady extends SheetEvent {
  const SheetReady({
    required this.totalSteps,
    required this.stepQuarters,
    required this.stepMeasures,
  });

  final int totalSteps;

  /// cursor 步号 → 该步起始位置（四分音符单位）。
  final Map<int, double> stepQuarters;

  /// cursor 步号 → 小节下标，编辑器选中高亮时定位用。
  final Map<int, int> stepMeasures;
}

/// 编辑器点击谱面音符：事件身份 (小节, 谱表, 声部内事件序号)，均 0 基
/// （谱表 0 = 右手 staff 1）。
class SheetNoteClicked extends SheetEvent {
  const SheetNoteClicked({
    required this.measure,
    required this.staff,
    required this.eventIndex,
  });

  final int measure;
  final int staff;
  final int eventIndex;
}

class SheetError extends SheetEvent {
  const SheetError(this.message);
  final String message;
}

class SheetUnknownEvent extends SheetEvent {
  const SheetUnknownEvent(this.raw);
  final String raw;
}

/// 曲谱 WebView 控制器：封装 Dart→JS 命令与 JS→Dart 事件。
class SheetWebviewController {
  final _events = StreamController<SheetEvent>.broadcast();
  final _pageReady = Completer<void>();

  Stream<SheetEvent> get events => _events.stream;
  Future<void> get pageReady => _pageReady.future;

  InAppWebViewController? _webView;

  void attach(InAppWebViewController webView) {
    _webView = webView;
  }

  void handleEvent(SheetEvent event) {
    if (event is SheetPageReady && !_pageReady.isCompleted) {
      _pageReady.complete();
    }
    _events.add(event);
  }

  Future<dynamic> _call(Map<String, dynamic> cmd) {
    final w = _webView;
    if (w == null) return Future.value(null);
    return w.callAsyncJavaScript(
      functionBody: 'return await window.EJMusic.handle(cmd);',
      arguments: {'cmd': cmd},
    );
  }

  Future<void> loadMusicXml(String xml) async =>
      _call({'op': 'load', 'xml': xml});
  Future<void> cursorTo(int step) async =>
      _call({'op': 'cursorTo', 'step': step});
  Future<void> selectStep(int step) async =>
      _call({'op': 'select', 'step': step});
  Future<void> cursorReset() async => _call({'op': 'cursorReset'});
  Future<void> setZoom(double zoom) async =>
      _call({'op': 'setZoom', 'zoom': zoom});

  /// 集成测试用：在宿主页执行 JS 并返回结果（callAsyncJavaScript 语义）。
  Future<dynamic> debugEvalJs(String functionBody) async {
    final w = _webView;
    if (w == null) return null;
    final r = await w.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {},
    );
    return r?.value;
  }

  void dispose() {
    _events.close();
  }
}
