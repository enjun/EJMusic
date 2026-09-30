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

  // 与设计系统语义色同源，保证键盘高亮与全站状态色一致
  static const _whiteIdle = Color(0xFFF6F6F8);
  static const _whitePressed = Color(0xFFC3C7D4);
  static const _whiteHint = Color(0xFFFFDE8A);
  static const _whiteCorrect = Color(0xFF9CDDAF);
  static const _whiteWrong = Color(0xFFF1A6A1);

  static const _blackIdle = Color(0xFF23252D);
  static const _blackPressed = Color(0xFF4A4E5C);
  static const _blackHint = Color(0xFFD69A22);
  static const _blackCorrect = Color(0xFF2E9E5B);
  static const _blackWrong = Color(0xFFC0392B);

  static const _labelColor = Color(0xFF8A8D9C);

  bool _isBlack(int midi) {
    const blacks = {1, 3, 6, 8, 10};
    return blacks.contains(midi % 12);
  }

  Color _whiteTint(int midi) {
    if (wrong.contains(midi)) return _whiteWrong;
    if (correct.contains(midi)) return _whiteCorrect;
    if (pressed.contains(midi)) return _whitePressed;
    if (hint.contains(midi)) return _whiteHint;
    return _whiteIdle;
  }

  Color _blackTint(int midi) {
    if (wrong.contains(midi)) return _blackWrong;
    if (correct.contains(midi)) return _blackCorrect;
    if (pressed.contains(midi)) return _blackPressed;
    if (hint.contains(midi)) return _blackHint;
    return _blackIdle;
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

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0E0F14),
    );

    // 白键：底部圆角 + 键缝，末段留出指板渐暗区
    final whiteRadius = Radius.circular(whiteW * 0.16);
    final seam = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var i = 0; i < whites.length; i++) {
      final m = whites[i];
      final rect = Rect.fromLTWH(i * whiteW + 0.5, 0, whiteW - 1, size.height);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          bottomLeft: whiteRadius,
          bottomRight: whiteRadius,
        ),
        Paint()..color = _whiteTint(m),
      );

      // 键缝，让相邻白键有清晰分隔
      canvas.drawLine(
        Offset(i * whiteW + 0.5, 0),
        Offset(i * whiteW + 0.5, size.height),
        seam,
      );

      // C 键标注
      if (m % 12 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: 'C${m ~/ 12 - 1}',
            style: TextStyle(
              fontSize: (whiteW * 0.34).clamp(9.0, 13.0),
              color: _labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            i * whiteW + (whiteW - tp.width) / 2,
            size.height - tp.height - 5,
          ),
        );
      }
    }

    // 黑键：圆角 + 落地阴影 + 顶部高光
    final blackRadius = Radius.circular(blackW * 0.22);
    for (var i = 0; i < whites.length - 1; i++) {
      final left = whites[i];
      final right = whites[i + 1];
      if (right - left != 2) continue; // EF/BC 无黑键
      final black = right - 1;
      if (black < lowMidi || black > highMidi) continue;
      final bx = (i + 1) * whiteW - blackW / 2;
      final rect = Rect.fromLTWH(bx, 0, blackW, blackH);
      final rrect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: blackRadius,
        bottomRight: blackRadius,
      );

      canvas.drawRRect(
        rrect.shift(const Offset(0, 2)),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawRRect(rrect, Paint()..color = _blackTint(black));

      if (!pressed.contains(black) &&
          !correct.contains(black) &&
          !wrong.contains(black) &&
          !hint.contains(black)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx + 1.5, 1, blackW - 3, blackH * 0.34),
            Radius.circular(blackW * 0.18),
          ),
          Paint()..color = const Color(0x1AFFFFFF),
        );
      }
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
