import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 琴键高亮状态。
enum KeyState { normal, pressed, correct, wrong, hint }

/// 屏幕虚拟钢琴键盘（CustomPaint 自绘）。
///
/// [lowMidi]~[highMidi] 为可见窗口；黑白键命中计算、五态高亮、
/// 支持按下回调与滑动滑奏。
class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    super.key,
    required this.lowMidi,
    required this.highMidi,
    this.pressed = const {},
    this.correct = const {},
    this.wrong = const {},
    this.hint = const {},
    this.onKeyDown,
    this.onKeyUp,
  }) : assert(lowMidi <= highMidi);

  final int lowMidi;
  final int highMidi;
  final Set<int> pressed;
  final Set<int> correct;
  final Set<int> wrong;
  final Set<int> hint;
  final void Function(int midi)? onKeyDown;
  final void Function(int midi)? onKeyUp;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  int? _downKey;

  bool _isBlack(int midi) {
    const blacks = {1, 3, 6, 8, 10};
    return blacks.contains(midi % 12);
  }

  /// 窗口内白键（含首端可能缺的黑键归属处理：对齐到 C）。
  List<int> get _whiteKeys => [
        for (var m = widget.lowMidi; m <= widget.highMidi; m++)
          if (!_isBlack(m)) m,
      ];

  int? _hitKey(Offset local) {
    final size = context.size;
    if (size == null || size.width <= 0) return null;
    final whites = _whiteKeys;
    if (whites.isEmpty) return null;
    final whiteW = size.width / whites.length;
    final blackW = whiteW * 0.62;
    final blackH = size.height * 0.62;

    // 黑键优先（上层）
    if (local.dy <= blackH) {
      for (var wi = 0; wi < whites.length - 1; wi++) {
        final left = whites[wi];
        final right = whites[wi + 1];
        // C-D EF-G-A B 布局：仅半音关系的白键间有黑键
        final iv = (right - left) == 2 ? right - 1 : null;
        if (iv == null) continue;
        final bx = (wi + 1) * whiteW - blackW / 2;
        if (local.dx >= bx && local.dx <= bx + blackW) {
          if (iv >= widget.lowMidi && iv <= widget.highMidi) return iv;
        }
      }
    }
    final wi = (local.dx / whiteW).floor().clamp(0, whites.length - 1);
    return whites[wi];
  }

  void _handleDown(Offset local) {
    final key = _hitKey(local);
    if (key == null) return;
    _downKey = key;
    widget.onKeyDown?.call(key);
  }

  void _handleMove(Offset local) {
    final key = _hitKey(local);
    if (key == _downKey) return;
    if (_downKey != null) widget.onKeyUp?.call(_downKey!);
    _downKey = key;
    if (key != null) widget.onKeyDown?.call(key);
  }

  void _handleUp() {
    if (_downKey != null) widget.onKeyUp?.call(_downKey!);
    _downKey = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _handleDown(e.localPosition),
      onPointerMove: (e) {
        if (e.buttons != 0) _handleMove(e.localPosition);
      },
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      child: CustomPaint(
        painter: _KeyboardPainter(
          lowMidi: widget.lowMidi,
          highMidi: widget.highMidi,
          pressed: widget.pressed,
          correct: widget.correct,
          wrong: widget.wrong,
          hint: widget.hint,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _KeyboardPainter extends CustomPainter {
  _KeyboardPainter({
    required this.lowMidi,
    required this.highMidi,
    required this.pressed,
    required this.correct,
    required this.wrong,
    required this.hint,
  });

  final int lowMidi;
  final int highMidi;
  final Set<int> pressed;
  final Set<int> correct;
  final Set<int> wrong;
  final Set<int> hint;

  bool _isBlack(int midi) {
    const blacks = {1, 3, 6, 8, 10};
    return blacks.contains(midi % 12);
  }

  Color _whiteTint(int midi) {
    if (wrong.contains(midi)) return const Color(0xFFE57373);
    if (correct.contains(midi)) return const Color(0xFF81C784);
    if (pressed.contains(midi)) return const Color(0xFFB0BEC5);
    if (hint.contains(midi)) return const Color(0xFFFFD54F);
    return Colors.white;
  }

  Color _blackTint(int midi) {
    if (wrong.contains(midi)) return const Color(0xFFC62828);
    if (correct.contains(midi)) return const Color(0xFF2E7D32);
    if (pressed.contains(midi)) return const Color(0xFF546E7A);
    if (hint.contains(midi)) return const Color(0xFFF9A825);
    return const Color(0xFF222222);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final whites = [
      for (var m = lowMidi; m <= highMidi; m++)
        if (!_isBlack(m)) m,
    ];
    if (whites.isEmpty || size.width <= 0) return;
    final whiteW = size.width / whites.length;
    final blackW = whiteW * 0.62;
    final blackH = size.height * 0.62;

    final bgPaint = Paint()..color = const Color(0xFF121212);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 白键
    for (var i = 0; i < whites.length; i++) {
      final m = whites[i];
      final rect = Rect.fromLTWH(i * whiteW + 0.5, 0.5, whiteW - 1, size.height - 1);
      canvas.drawRect(rect, Paint()..color = _whiteTint(m));
      // C 标记
      if (m % 12 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: 'C${m ~/ 12 - 1}',
            style: TextStyle(fontSize: whiteW * 0.38, color: const Color(0xFF9E9E9E)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(i * whiteW + (whiteW - tp.width) / 2, size.height - tp.height - 3));
      }
    }

    // 黑键
    for (var i = 0; i < whites.length - 1; i++) {
      final left = whites[i];
      final right = whites[i + 1];
      if (right - left != 2) continue; // EF/BC 无黑键
      final black = right - 1;
      if (black < lowMidi || black > highMidi) continue;
      final bx = (i + 1) * whiteW - blackW / 2;
      final rect = Rect.fromLTWH(bx, 0, blackW, blackH);
      final rrect = RRect.fromRectAndCorners(rect,
          bottomLeft: const Radius.circular(3),
          bottomRight: const Radius.circular(3));
      canvas.drawRRect(rrect, Paint()..color = _blackTint(black));
    }
  }

  @override
  bool shouldRepaint(_KeyboardPainter old) =>
      old.lowMidi != lowMidi ||
      old.highMidi != highMidi ||
      !setEquals(old.pressed, pressed) ||
      !setEquals(old.correct, correct) ||
      !setEquals(old.wrong, wrong) ||
      !setEquals(old.hint, hint);
}
