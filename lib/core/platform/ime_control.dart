import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Windows 输入法临时开关。
///
/// 中文输入法（HKL 0x0804 系）激活时，字母键先被 IME 合成截走，
/// 应用只能收到 VK_PROCESSKEY——编辑器琴键映射（A–L/W–P）、演奏页 K
/// 快捷键会全部失效；数字、方向键、Insert 不受影响。
/// 标准解法：把 Flutter 窗口（含子窗口）的 IME 关联上下文置空。
/// 文本框获焦时必须恢复，否则曲名等中文输入不可用（编辑器有监听处理）。
class ImeControl {
  ImeControl._();

  static const String _className = 'FLUTTER_RUNNER_WIN32_WINDOW';

  /// hwnd 地址 → 原 HIMC 指针；非空表示当前处于禁用状态。
  static final Map<int, Pointer<Void>> _saved = {};

  static void disable() {
    if (!Platform.isWindows || _saved.isNotEmpty) return;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final findWindowW = user32
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Utf16>),
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Utf16>)
          >('FindWindowW');
      final findWindowExW = user32
          .lookupFunction<
            Pointer<Void> Function(
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Utf16>,
              Pointer<Utf16>,
            ),
            Pointer<Void> Function(
              Pointer<Void>,
              Pointer<Void>,
              Pointer<Utf16>,
              Pointer<Utf16>,
            )
          >('FindWindowExW');
      final klass = _className.toNativeUtf16();
      try {
        final main = findWindowW(klass.cast(), nullptr);
        if (main == nullptr) return;
        final imm32 = DynamicLibrary.open('imm32.dll');
        final associate = imm32
            .lookupFunction<
              Pointer<Void> Function(Pointer<Void>, Pointer<Void>),
              Pointer<Void> Function(Pointer<Void>, Pointer<Void>)
            >('ImmAssociateContext');
        _associateNull(main, associate);
        // 键盘焦点在 FLUTTERVIEW 子窗口上，IME 上下文按窗口各自关联
        var child = findWindowExW(main, nullptr, nullptr, nullptr);
        while (child != nullptr) {
          _associateNull(child, associate);
          child = findWindowExW(main, child, nullptr, nullptr);
        }
      } finally {
        calloc.free(klass);
      }
    } catch (_) {
      // FFI 不可用（非标准 runner 等）时静默：琴键在中文 IME 下退化，其余功能不受影响
    }
  }

  static void _associateNull(
    Pointer<Void> hwnd,
    Pointer<Void> Function(Pointer<Void>, Pointer<Void>) associate,
  ) {
    final prev = associate(hwnd, nullptr);
    _saved[hwnd.address] = prev;
  }

  static void restore() {
    if (!Platform.isWindows || _saved.isEmpty) return;
    final snapshot = _saved.entries.map((e) => (e.key, e.value)).toList();
    _saved.clear();
    try {
      final imm32 = DynamicLibrary.open('imm32.dll');
      final associate = imm32
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>, Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>, Pointer<Void>)
          >('ImmAssociateContext');
      for (final (address, himc) in snapshot) {
        associate(Pointer<Void>.fromAddress(address), himc);
      }
    } catch (_) {
      // 同 disable：静默失败
    }
  }
}
