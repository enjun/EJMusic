/// 纯 Dart 感知哈希（pHash, DCT 64-bit），用于曲谱图片去重。
library;

import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// 计算 64-bit pHash，返回 16 位十六进制字符串（大端，首比特恒 0 补位）。
///
/// 流程：灰度 → 缩放到 32x32 → 二维 DCT → 取左上 8x8（跳过 DC 分量）
/// 按中位数阈值生成 63 比特。低频系数先做 1e-4 精度量化，
/// 避免纯色/空白图的浮点噪声导致哈希不稳定。
String computePHash(img.Image source) {
  final small = img.copyResize(
    source,
    width: 32,
    height: 32,
    interpolation: img.Interpolation.average,
  );

  final pixels = List<double>.generate(32 * 32, (i) {
    final p = small.getPixel(i % 32, i ~/ 32);
    return img.getLuminanceRgb(p.r.toInt(), p.g.toInt(), p.b.toInt()).toDouble();
  });

  // 近空白图吸附：灰度动态范围极小（≤2，如空白页或纯色图）时，
  // 缩放产生的 ±1 抖动会成为主要"信号"导致哈希不稳定，统一取均值消除。
  var mn = pixels[0];
  var mx = pixels[0];
  for (final v in pixels) {
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }
  if (mx - mn <= 2) {
    final mean = pixels.reduce((a, b) => a + b) / pixels.length;
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] = mean;
    }
  }

  final dct = _dct2d(pixels, 32);
  // 左上 8x8 低频分量，跳过 [0][0] DC 项（保持频域顺序）
  final lowFreq = <double>[];
  for (var u = 0; u < 8; u++) {
    for (var v = 0; v < 8; v++) {
      if (u == 0 && v == 0) continue;
      lowFreq.add(_quantize(dct[u * 32 + v]));
    }
  }
  final sorted = [...lowFreq]..sort();
  final median = sorted[sorted.length ~/ 2];

  final bits = List<bool>.filled(64, false); // 首位补 0，凑 64 比特
  for (var i = 0; i < 63; i++) {
    bits[i + 1] = lowFreq[i] > median;
  }
  // bits 大端序转十六进制（逐半字节，不经过 int.parse/toRadixString，
  // 规避 64 位有符号整数溢出）
  const hexDigits = '0123456789abcdef';
  final sb = StringBuffer();
  for (var i = 0; i < 16; i++) {
    var nib = 0;
    for (var j = 0; j < 4; j++) {
      nib = (nib << 1) | (bits[i * 4 + j] ? 1 : 0);
    }
    sb.write(hexDigits[nib]);
  }
  return sb.toString();
}

double _quantize(double v) => (v * 10000).roundToDouble() / 10000;

/// 行优先 n x n 输入的分离式 DCT-II（先行后列）。
List<double> _dct2d(List<double> input, int n) {
  final temp = List<double>.filled(n * n, 0);
  final out = List<double>.filled(n * n, 0);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      var sum = 0.0;
      for (var i = 0; i < n; i++) {
        sum += input[y * n + i] * _cosTable(x, i, n);
      }
      temp[y * n + x] = sum;
    }
  }
  for (var x = 0; x < n; x++) {
    for (var y = 0; y < n; y++) {
      var sum = 0.0;
      for (var i = 0; i < n; i++) {
        sum += temp[i * n + x] * _cosTable(y, i, n);
      }
      out[y * n + x] = sum;
    }
  }
  return out;
}

double _cosTable(int u, int x, int n) {
  final c = u == 0 ? math.sqrt(0.5) : 1.0;
  return c * math.cos((2 * x + 1) * u * math.pi / (2 * n));
}

const _nibblePopcount = [0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4];

int _hexValue(int ch) {
  if (ch >= 0x30 && ch <= 0x39) return ch - 0x30;
  if (ch >= 0x61 && ch <= 0x66) return ch - 0x61 + 10;
  if (ch >= 0x41 && ch <= 0x46) return ch - 0x41 + 10;
  throw FormatException('非法十六进制字符: ${String.fromCharCode(ch)}');
}

/// 两个十六进制 pHash 的汉明距离（不解析为整数，规避 64 位溢出）。
int hammingDistance(String hashA, String hashB) {
  if (hashA.length != hashB.length) {
    throw ArgumentError('哈希长度不一致: $hashA vs $hashB');
  }
  var distance = 0;
  for (var i = 0; i < hashA.length; i++) {
    distance += _nibblePopcount[_hexValue(hashA.codeUnitAt(i)) ^ _hexValue(hashB.codeUnitAt(i))];
  }
  return distance;
}
