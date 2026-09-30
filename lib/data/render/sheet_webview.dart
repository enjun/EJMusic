import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/ui/app_theme.dart' show SheetThemeColors;

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
          quarter: m['q'] is num ? (m['q'] as num).toDouble() : null,
          entryIdx: m['gi'] is num ? (m['gi'] as num).toInt() : null,
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
    this.quarter,
    this.entryIdx,
  });

  final int measure;
  final int staff;
  final int eventIndex;

  /// 所点事件的 onset（四分音符单位）；旧版宿主页不带此字段时为 null。
  final double? quarter;

  /// 所点事件在宿主页图形事件序表中的全局下标（光标精确校正用）。
  final int? entryIdx;
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

  /// [rescan] = false 时跳过全谱走光标（步号表约 0.5-1s，是编辑渲染
  /// 卡顿的大头）：内容小改的重渲染复用已有步号表，高亮定位靠 delta
  /// 校正不受影响。首次加载或换曲必须 rescan: true。
  Future<void> loadMusicXml(String xml, {double? zoom, bool rescan = true}) =>
      _call({'op': 'load', 'xml': xml, 'zoom': ?zoom, 'rescan': rescan});
  Future<void> cursorTo(int step) async =>
      _call({'op': 'cursorTo', 'step': step});
  Future<void> selectStep(int step, {int? entryIdx}) async =>
      _call({'op': 'select', 'step': step, 'idx': ?entryIdx});
  Future<void> cursorReset() async => _call({'op': 'cursorReset'});
  Future<void> setZoom(double zoom) async =>
      _call({'op': 'setZoom', 'zoom': zoom});

  /// 按应用主题刷新谱面底色（设计系统色 → 宿主页 CSS 变量）。
  Future<void> setThemeFrom(SheetThemeColors c) => setTheme(
    bg: c.background,
    fg: c.foreground,
    paper: c.paper,
    shadow: c.shadow,
    outline: c.outline,
  );

  /// 把当前主题的底色/文字色/纸色推给宿主页，使谱面与全站视觉一致。
  Future<void> setTheme({
    required Color bg,
    required Color fg,
    required Color paper,
    Color? shadow,
    Color? outline,
  }) => _call({
    'op': 'setTheme',
    'bg': _css(bg),
    'fg': _css(fg),
    'paper': _css(paper),
    if (shadow != null) 'shadow': _css(shadow),
    if (outline != null) 'outline': _css(outline),
  });

  static String _css(Color c) =>
      'rgba(${(c.r * 255).round()}, ${(c.g * 255).round()}, '
      '${(c.b * 255).round()}, ${c.a.toStringAsFixed(3)})';

  /// 高亮谱面上的事件 (小节 m, 谱表 s 0基, 声部内事件序号 k)。
  /// 蓝色填充该音符符头，同时把绿光标定位到该事件（页面按步号 +
  /// delta 校正）；[reveal] 时滚动让光标可见。重渲染后由编辑器重发，
  /// 借此同时恢复蓝选中与绿光标位置。
  Future<void> highlight(int m, int s, int k, {bool reveal = false}) async =>
      _call({'op': 'highlight', 'm': m, 's': s, 'k': k, 'reveal': reveal});

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
